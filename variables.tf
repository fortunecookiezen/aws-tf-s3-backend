variable "organization" {
  type        = string
  description = "Organization name, used as the prefix of the state bucket name."
}
variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, prod), included in the state bucket name."
}
variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources. A Name tag set here is overridden per resource."
  default     = {}
}
