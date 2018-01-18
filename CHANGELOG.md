# Changelog

## v0.1.1-dev

* Encode the username in Base64 in the authentication cookie to allow it
  contains dots

## v0.1.0

* Login store specification
* `:mnesia` login store with helpers to create, clear an drop the table
* Plugs to register logins, authenticate and logout
* API to manage logins
* Old login cleaner
