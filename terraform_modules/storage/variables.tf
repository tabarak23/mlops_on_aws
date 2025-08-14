variable "project_name" {
  description = "gie project name"
  type = string
}

variable "stage" {
  type= string
  description= "GIVE the enviironmetn name"
}

variable "enable_lifecycle_rules" {
  type    = bool
  default = false
}
