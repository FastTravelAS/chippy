namespace :chippy do
  task start: :environment do
    require "chippy"
    puts "Starting chip reader server"
    Chippy.start
  end

  task simulate_traffic: :environment do
    if Rails.env.production?
      puts "Cannot run simulator in production"
    else
      require "chippy/simulator"
      puts "Starting simulator"
      Chippy::Simulator.run
    end
  end
end
