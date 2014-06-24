AuthSource.without_auditing do
  # Auth sources
  src = AuthSourceInternal.find_by_type "AuthSourceInternal"
  src ||= AuthSourceInternal.create :name => "Internal"

  admin_firstname = ENV['admin_username'] || 'Admin'
  admin_lastname = ENV['admin_lastname'] || 'User'
  admin_login = ENV['admin_login'] || 'admin'
  admin_password = ENV['admin_password'] || 'changeme'
  admin_email = ENV['admin_email'] || Setting[:administrator]

  # Users
  unless User.find_by_login(admin_login).present?
    User.without_auditing do
      user = User.new(:login => admin_login, :firstname => admin_firstname, :lastname => admin_lastname, :mail => admin_email)
      user.admin = true
      user.auth_source = src
      user.password = admin_password
      User.current = user
      raise "Unable to create admin user: #{format_errors user}" unless user.save
    end
  end
end
