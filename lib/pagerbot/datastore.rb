# class for reading from the database and pagerduty
module PagerBot
  class DataStore
    include SemanticLogger::Loggable

    def db
      return @db unless @db.nil?
      Mongo::Logger.logger.level = ::Logger::INFO
      if ENV['MONGODB_URI']
        client = Mongo::Client.new(ENV['MONGODB_URI'])
      else
        client = Mongo::Client.new('mongodb://localhost:27017', :database => 'pagerbot')
      end

      @db = client.database
    end

    def get_pagerduty
      PagerBot::PagerDuty.new()
    end

    # get list of collection objects (schedules, users) from pagerduty
    def pd_list_of(collection_name, pagerduty=nil)
      pagerduty ||= get_pagerduty
      logger.measure_info "Fetching collection from pagerduty.", collection_name: collection_name do
        PagerBot::Utilities
          .paginate('/'+collection_name, collection_name.to_sym, pagerduty)
          .values
          .sort_by { |u| u['name'] }
          .map do |member|
            member.delete('_id')
            member["aliases"] ||= []
            ActiveSupport::HashWithIndifferentAccess.new member
          end
      end
    end

    def db_get_list_of(collection_name, order_field='name')
      result = db[collection_name].find({}).to_a.sort_by { |u| u[order_field] }
      result.map do |hash|
        hash["aliases"] ||= []
        hash.delete('_id')
        ActiveSupport::HashWithIndifferentAccess.new hash
      end
    end

    def get_or_create(collection_name, default={})
      collection = db[collection_name]
      current_value = collection.find().first

      if current_value.nil?
        collection.update_one({}, default)
        current_value = BSON::Document.new default
      end
      current_value.delete('_id')
      current_value
    end


    def update_listed_collection(collection_name, member, id_field=:id)
      member.delete('_id')
      query = {id_field => member[id_field]}
      db[collection_name].update_one(query, {'$set' => member}, :upsert => true)
    end

    def update_listed(collection_name, members, id_field=:id)
      members.each do |member|
        update_listed_collection(collection_name, member, id_field)
      end
    end

    def need_to_update_list(collection_name)
      findQuery = {collection: collection_name}
      last_time = db[:update_times].find(findQuery).first
      if last_time.nil?
        last_time = {'collection' => collection_name, 'time' => 0}
      end

      update_needed = Time.now.to_i - last_time.fetch('time') > 120
      if update_needed
        last_time['time'] = Time.now.to_i
        db[:update_times].update_one(findQuery, {'$set' => last_time}, :upsert => true)
      end

      update_needed
    end

    # Refreshes collection (users, schedules) by reloading from pagerduty
    # if enough time has passed from last update
    def update_collection!(collection_name, force_reload=false)
      database_collection = db_get_list_of(collection_name)
      if database_collection.empty?
        logger.info("Creating #{collection_name} list for the first time!")
        pagerduty_collection = pd_list_of(collection_name)
        update_listed(collection_name, pagerduty_collection)
        return [pagerduty_collection, [], []]
      end

      added = removed = []
      if force_reload || need_to_update_list(collection_name)
        added, removed = PagerBot::Utilities.update_lists(
          pd_list_of(collection_name), database_collection)

        update_listed(collection_name, added)
        logger.info("Added to #{collection_name}: #{added.map{|m| m['id']}}")

        removed_ids = removed.map {|m| m['id']}
        db[collection_name].delete_many(id: {'$in' => removed_ids})
        logger.info("Removed from #{collection_name}: #{removed_ids}")

        database_collection = db_get_list_of(collection_name)

        logger.info "Refreshed collection.",
          collection_name: collection_name,
          total: database_collection.length,
          added: added.length,
          removed: removed.length
      end

      [database_collection, added, removed]
    end
  end
end
