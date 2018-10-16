require "spaceship"

Spaceship.login()
Spaceship.select_team()

devices = Spaceship.device.all
File.open('devices.txt', 'w') do |f|
  f.puts "Device ID\tDevice Name"
  devices.each do |device|
    f.puts "#{device.udid}\t#{device.name}"
  end
end

exit
