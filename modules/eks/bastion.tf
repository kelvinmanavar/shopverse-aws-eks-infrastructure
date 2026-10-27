# SSM-managed bastion: an EC2 instance in a public subnet reachable ONLY
# through AWS Systems Manager Session Manager. No key pair, no inbound SSH.
# Operators and CI use it to reach the private-only EKS API endpoint.

# Latest Amazon Linux 2023 AMI (x86_64) via the AWS-published SSM parameter.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------------------
# Instance profile with SSM core permissions
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.name_prefix}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json

  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion-role" })
}

# Grants Session Manager connectivity; no inbound ports required.
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.bastion.name
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion-profile" })
}

# ---------------------------------------------------------------------------
# Bastion security group: egress only, NO ingress (no port 22, ever)
# ---------------------------------------------------------------------------

resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "SSM bastion SG: egress only, no inbound SSH"
  vpc_id      = var.vpc_id

  # Intentionally no ingress rules. Session Manager works over the SSM agent's
  # outbound connection, so the bastion needs no open inbound ports.
  egress {
    description = "Allow all outbound (SSM endpoints, cluster API)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion-sg" })
}

# ---------------------------------------------------------------------------
# Bastion instance
# ---------------------------------------------------------------------------

resource "aws_instance" "bastion" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.bastion_instance_type
  subnet_id              = var.public_subnet_ids[0]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  # No key_name on purpose: access is exclusively via SSM Session Manager.

  metadata_options {
    http_tokens   = "required" # enforce IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion" })
}

# ---------------------------------------------------------------------------
# Bastion -> private EKS API reachability
# ---------------------------------------------------------------------------
# The cluster API endpoint is private-only. The EKS-managed cluster security
# group gates inbound 443 to the control plane, so the bastion SG must be
# explicitly allowed as a source for `kubectl` over SSM Session Manager to work.

resource "aws_vpc_security_group_ingress_rule" "cluster_api_from_bastion" {
  security_group_id            = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow SSM bastion to reach the private EKS API (443)"

  tags = merge(var.tags, { Name = "${var.name_prefix}-cluster-api-from-bastion" })
}

# ---------------------------------------------------------------------------
# Bastion -> EKS authorization (access entry, cluster-admin)
# ---------------------------------------------------------------------------
# The cluster uses authentication_mode = "API", so Kubernetes access is granted
# via EKS access entries rather than the aws-auth ConfigMap. The bastion runs
# with aws_iam_role.bastion via its instance profile, so any operator who opens
# an SSM Session Manager session onto the bastion inherits this role and is
# authorized against the cluster. Granted cluster-admin per design.

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.cluster.name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"

  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion-access-entry" })
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = aws_eks_cluster.cluster.name
  principal_arn = aws_iam_role.bastion.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}
