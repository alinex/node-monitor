# Configuration Schema
# =================================================

# Contacts
# -------------------------------------------------

contact =
  title: "Contacts"
  description: "the possible contacts to be referred from controller for email alerts"
  type: 'object'
  default: {}
  entries: [
    type: 'or'
    or: [
      title: "Contact Group"
      description: "the list of references in the group specifies the individual
        contacts"
      type: 'array'
      toArray: true
      minLength: 1
      entries:
        type: 'string'
    ,
      title: "Contact Details"
      description: "the name and email address for a specific contact"
      type: 'object'
      mandatoryKeys: ['name']
      allowedKeys: true
      keys:
        name:
          title: "Name"
          description: "the full name of the contact"
          type: 'string'
        position:
          title: "Position"
          description: "the position within the organization (informal)"
          type: 'string'
        company:
          title: "Company"
          description: "the company name this person belongs to"
          type: 'string'
        email:
          title: "Email"
          description: "the email address to send alerts"
          type: 'string'
        phone:
          title: "Phone"
          description: "the phone number used for direct contact"
          type: 'string'
    ]
  ]

# Email Templates
# -------------------------------------------------

email =
  title: "Email Templates"
  description: "the possible templates used for sending emails"
  type: 'object'
  default: {}

# Email Templates
# -------------------------------------------------

controller =
  title: "Controller"
  description: "the list of controllers to check"
  type: 'object'
  default: {}

# Complete Schema Definition
# -------------------------------------------------

module.exports =
  title: "Monitor Setup"
  description: "the configuration for the monitor system"
  type: 'object'
  allowedKeys: true
  keys:
    contact: contact
    email: email
    controller: controller
