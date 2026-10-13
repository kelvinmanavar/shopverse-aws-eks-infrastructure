# Network foundation: VPC across 2 AZs with 2 public + 2 private subnets, an
# internet gateway, NAT gateway(s), route tables, and optional VPC flow logs.
# All other infrastructure modules depend on this module's outputs.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use explicit AZ names when provided, otherwise derive the first az_count
  # zones from the region. Deterministic for a given region/input (Req 9.5).
  azs = length(var.azs) > 0 ? slice(var.azs, 0, var.az_count) : slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Deterministic per-AZ subnet CIDRs carved from the VPC CIDR. Public subnets
  # take the low indices, private subnets are offset by az_count so the two
  # tiers never overlap. With a /16 and newbits=8 these are /24 subnets.
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + var.az_count)]

  # NAT strategy: one shared NAT (dev) vs one per AZ (prod).
  nat_gateway_count = var.single_nat_gateway ? 1 : var.az_count
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# ---------------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
    # EKS load-balancer discovery for internet-facing LBs.
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${local.azs[count.index]}"
    # EKS load-balancer discovery for internal LBs.
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ---------------------------------------------------------------------------
# NAT gateways + Elastic IPs
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name_prefix}-nat-eip-${count.index}" })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  # NAT gateways live in public subnets. With a single shared NAT it sits in
  # the first public subnet; with per-AZ NAT each sits in its AZ's public subnet.
  subnet_id = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "${var.name_prefix}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.igw]
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------

# One public route table shared by all public subnets, default route to IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per AZ so each AZ can route to its own NAT. When a
# single shared NAT is used, every private route table targets that one NAT.
resource "aws_route_table" "private" {
  count = var.az_count

  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-private-rt-${local.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count = var.az_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # Shared NAT -> index 0; per-AZ NAT -> this AZ's NAT.
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.nat[0].id : aws_nat_gateway.nat[count.index].id
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
