require_relative 'lib/task'

namespace :viky do

  desc "Setup database and statistics"
  task :setup => [:environment] do |t, args|
    # Database related
    connected = ::ActiveRecord::Base.connection_pool.with_connection(&:active?) rescue false
    if connected
      if ::ActiveRecord::SchemaMigration.table_exists?
        Rake::Task["db:migrate"].invoke
      else
        Rake::Task["db:structure:load"].invoke
        #Rake::Task["db:schema:load"].invoke
        Rake::Task["db:seed"].invoke
      end
    else
      Rake::Task["db:setup"].invoke
    end
    Rake::Task["viky:clear_old_running_entities_imports"].invoke
    Rake::Task["viky:clear_agent_regression_checks_run_state"].invoke

    # Statistics related
    Rake::Task["statistics:setup"].invoke
    Rake::Task["statistics:reindex:all"].invoke
  end

  desc "Clear running entities imports older than one hour"
  task :clear_old_running_entities_imports => [:environment] do |t, args|
    if ActiveRecord::Base.connection.table_exists? "entities_imports"
      EntitiesImport.running.where("created_at < ?", 1.hours.ago).delete_all
    end
  end

  desc 'Run every regression checks on every agents'
  task :run_agent_regression_checks => [:environment] do |_, _|
    Agent.find_each do |agent|
      agent.run_regression_checks
    end
  end

  desc 'Reset every regression checks run state on every agents'
  task :clear_agent_regression_checks_run_state => [:environment] do |_, _|
    Agent.update_all(nlp_updated_at: nil)
  end
end
