namespace :statistics do

  desc 'Creates and configures stats indices'
  task setup: :environment do |t, args|
    fetch_template_configurations.each do |template_conf|
      index_base_name = template_conf['template'][0..-3]
      template_name = "template-#{index_base_name}"
      client = IndexManager.client
      create_template(client, template_name, template_conf)
      list_environments.each do |env|
        index_name = [index_base_name, env].join('-')
        create_index(client, index_name)
      end
    end
  end


  private
    def fetch_template_configurations
      template_config_dir = "#{Rails.root}/config/statistics"
      Dir.foreach(template_config_dir)
         .select { |filename| filename.downcase.end_with? '.json' }
         .map { |filename| JSON.parse(ERB.new(File.read("#{template_config_dir}/#{filename}")).result) }
    end

    def list_environments
      config = YAML.load(ERB.new(File.read("#{Rails.root}/config/statistics.yml")).result).symbolize_keys
      config.keys
        .reject { |env| env == :default }
        .map { |env| env.to_s }
    end

    def create_template(client, template_name, template_conf)
      begin
        client.indices.put_template name: template_name, body: template_conf
        puts Rainbow("Creation of index template #{template_name} succeed.").green
      rescue
        puts Rainbow("Creation of index template #{template_name} failed.").red
      end
    end

    def create_index(client, index_name)
      if client.indices.exists index: index_name
        puts Rainbow("Index #{index_name} already exists : skipping.").green
        return
      end
      begin
        client.indices.create index: index_name
        puts Rainbow("Creation of index #{index_name} succeed.").green
      rescue
        puts Rainbow("Creation of index #{index_name} failed.").red
      end
    end
end
