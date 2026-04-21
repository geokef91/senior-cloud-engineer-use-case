locals {
  # Consistent naming suffix used across all resources
  name_suffix = "${var.project}-${var.environment}"

  # Merged tags applied to every resource
  tags = merge(
    {
      environment = var.environment
      project     = var.project
      managed_by  = "terraform"
    },
    var.tags
  )
}
