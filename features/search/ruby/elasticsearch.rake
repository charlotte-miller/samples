# https://github.com/elasticsearch/elasticsearch-rails/tree/master/elasticsearch-rails#rake-tasks

STDOUT.sync = STDERR.sync = true
require 'ansi/progressbar'
require 'elasticsearch/rails/tasks/import'

namespace :elasticsearch do

  desc "Downloads the WordNet 3.0 synonyms database - might require sudo privlages for /var/lib"
  task :download_wordnet do
    [
      'cd /tmp && curl -o wordnet.tar.gz http://wordnetcode.princeton.edu/3.0/WNprolog-3.0.tar.gz',
      'cd /tmp && tar -zxvf wordnet.tar.gz',
      'cd /tmp && mv prolog/wn_s.pl /var/lib'
    ].each { |command| system(command) || raise( RuntimeError.new("FAILED TO EXECUTE: '#{command}'" )) }
  end


  task :import => 'import:model' # move original

  namespace :import do

    desc <<-DESC.gsub(/    /, '')
      Import all mappings from `app/models` (or use DIR environment variable) into a single index.

      All classes should declare a common `index_name`:

      class Article
        include Elasticsearch::Model

        index_name 'app_scoped_index'

        mappings do
          ...
        end
      end

      Usage:
        $ rake environment elasticsearch:import:combined DIR=app/models
    DESC
    task :combined => 'environment' do
      dir = ENV['DIR'].to_s != '' ? ENV['DIR'] : Rails.root.join("app/models")

      searchable_classes = Dir.glob(File.join("#{dir}/**/*.rb")).map do |path|
        model_filename = path[/#{Regexp.escape(dir.to_s)}\/([^\.]+).rb/, 1]

        next if model_filename.match(/^concerns\//i) # Skip concerns/ folder

        begin
          klass = model_filename.camelize.constantize
        rescue NameError
          require(path) ? retry : raise(RuntimeError, "Cannot load class '#{klass}'")
        rescue RuntimeError => e
          next if e.message =~ /^Circular dependency detected while autoloading constant/
        end

        # Skip if the class doesn't have Elasticsearch integration
        next unless klass.respond_to?(:__elasticsearch__) && klass.respond_to?(:mappings)
        klass
      end.compact

      # REBUILD deletes the index before building
      rebuild_once = ENV['REBUILD'] ? searchable_classes.map(&:index_name).uniq : []

      ## Update Each Class
      searchable_classes.each do |klass|
        puts "[IMPORT] Processing mappings for: #{klass}..."

        es_indices = Elasticsearch::Model.client.indices
        options = {index: klass.index_name }

        # Delete index once if REBUILD
        if rebuild_once.include? klass.index_name
          es_indices.delete(options) if es_indices.exists(options)
          rebuild_once.delete(klass.index_name)
        end

        # Find or create index
        es_indices.create(options.merge({ body:{settings: klass.settings.to_hash} })) unless es_indices.exists(options)
        es_indices.put_mapping(options.merge({
          type: klass.document_type,
          body: klass.mappings.to_hash,
          # ignore_conflicts:true,
        }))

      end

      # Run Import for each class using .custom_import or .import
      searchable_classes.each do |klass|
        puts "[IMPORTING] #{klass}..."
        defined?(klass.custom_import) ? klass.custom_import : klass.import
      end


      ## Import data into the newly created index
      # Rake::Task["elasticsearch:import:all"].invoke
    end

  end


end
