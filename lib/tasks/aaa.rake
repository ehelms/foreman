task :aaa => :environment do
  require 'rails/commands/console'
  Rails::Console.start(Rails.application)
end
