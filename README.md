# RailsLite

RailsLite is a lightweight version of Ruby-on-Rails built from scratch, featuring some of the basic functionality from Rails.

This particular construction includes a lightweight version of Active Record that includes model associations and table modification/lookup methods.

The goal of this project was to gain a thorough understanding of Ruby-on-Rails, Active Record, and backend frameworks in general.

## Features

### RailsLite

* HTTPSServer via WEBrick ruby server module.
* Replicates ActionController::Base with ControllerBase class, including render and redirect methods.
* Reads, evaluates, and renders ERB templates.
* Stores serialized session data in WEBrick cookie.
* Evaluates and stores params from URL, request body, and query string.
* Includes a router that tracks multiple routes, and matches them to their respective controller methods for execution.

### Active Record

* Automated table naming based on Active Record conventions.
* Getter and setter methods for table columns.
* Table modification methods: #add, #insert, #save, #update.
* Table Lookup methods: #all, #find, #where, #includes.
* Fully featured associations: belongs_to, has_many, has_one :through, has_many :through.
* Uses a Relation class to make #where lazy and stackable.