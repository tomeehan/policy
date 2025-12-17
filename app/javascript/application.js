// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "channels"
import "controllers"
import "src"

// Load after src so extensions work
import "lexxy"
import "@rails/actiontext"

import LocalTime from "local-time"
LocalTime.start()
