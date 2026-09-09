variable "name_prefix" {
  type = string
}

variable "databases" {
  description = "Catalog databases to create, keyed by short name."
  type = map(object({
    description  = optional(string, "")
    location_uri = optional(string)
  }))
  default = {}
}
