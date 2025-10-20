module Windows::User
  include Beaker::CommandFactory

  def user_list
    # Try PowerShell first (Windows Server 2016+)
    result = execute("powershell -Command \"Get-LocalUser | Select-Object -ExpandProperty Name\"", :accept_all_exit_codes => true)
    
    if result.exit_code == 0
      users = []
      result.stdout.each_line do |line|
        username = line.strip
        users << username unless username.empty?
      end

      yield result if block_given?

      return users unless users.empty?
    end

    # Fallback to wmic for older systems
    user_list_wmic
  end

  # @api private
  def user_list_wmic
    execute('cmd /c echo "" | wmic useraccount where localaccount="true" get name /format:value') do |result|
      users = []
      result.stdout.each_line do |line|
        users << (line.match(/^Name=(.+)/) or next)[1]
      end

      yield result if block_given?

      users
    end
  end

  # using powershell commands as wmic is deprecated in windows 2025
  def user_list_using_powershell
    execute('cmd /c echo "" | powershell.exe "Get-LocalUser | Select-Object -ExpandProperty Name"') do |result|
      users = []
      result.stdout.each_line do |line|
        users << line.strip or next
      end

      yield result if block_given?

      users
    end
  end

  def user_get(name)
    execute("net user \"#{name}\"") do |result|
      fail_test "failed to get user #{name}" if result.exit_code != 0

      yield result if block_given?
      result
    end
  end

  def user_present(name, &)
    execute("net user /add \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end

  def user_absent(name, &)
    execute("net user /delete \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end
end
