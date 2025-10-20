module PSWindows::Group
  include Beaker::CommandFactory

  def group_list
    # Try PowerShell first (Windows Server 2016+)
    result = execute("powershell -Command \"Get-LocalGroup | Select-Object -ExpandProperty Name\"", :accept_all_exit_codes => true)
    
    if result.exit_code == 0
      groups = []
      result.stdout.each_line do |line|
        groupname = line.strip
        groups << groupname unless groupname.empty?
      end

      yield result if block_given?

      return groups unless groups.empty?
    end

    # Fallback to wmic for older systems
    group_list_wmic
  end

  # @api private
  def group_list_wmic
    execute('cmd /c echo "" | wmic group where localaccount="true" get name /format:value') do |result|
      groups = []
      result.stdout.each_line do |line|
        groups << (line.match(/^Name=(.+)$/) or next)[1]
      end

      yield result if block_given?

      groups
    end
  end

  def group_get(name)
    execute("net localgroup \"#{name}\"") do |result|
      fail_test "failed to get group #{name}" if result.exit_code != 0

      yield result if block_given?
      result
    end
  end

  def group_gid(_name)
    raise NotImplementedError, "Can't retrieve group gid on a Windows host"
  end

  def group_present(name, &)
    execute("net localgroup /add \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end

  def group_absent(name, &)
    execute("net localgroup /delete \"#{name}\"", { :acceptable_exit_codes => [0, 2] }, &)
  end
end
