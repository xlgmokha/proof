# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
Mime::Type.register "application/scim+json", :scim

scim_parser = ActionDispatch::Request.parameter_parsers[:json]
original_parsers = ActionDispatch::Request.parameter_parsers
ActionDispatch::Request.parameter_parsers =
  original_parsers.merge(Mime[:scim].symbol => scim_parser)
