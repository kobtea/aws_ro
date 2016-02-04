require 'aws-sdk'

module AwsRo
  module EC2
    class Repository
      def initialize(client_options)
        @client_options = client_options
      end

      def client
        @client ||= Aws::EC2::Client.new(@client_options)
      end

      def all
        filters([]).to_a
      end

      def tags(filter_hash = {})
        Relation.new(self).tags(filter_hash)
      end

      def running
        Relation.new(self).running
      end

      def not_terminated
        Relation.new(self).not_terminated
      end

      def filters(filters)
        Relation.new(self).filters(filters)
      end

      def instance_ids(ids)
        Relation.new(self).instance_ids(ids)
      end

      class Relation
        extend Forwardable
        include Enumerable
        array_methods =
          (Array.instance_methods - Enumerable.instance_methods - Object.instance_methods)
        def_delegators :to_a, *array_methods

        def initialize(klass)
          @klass = klass
          @filters = []
          @instance_ids = []
        end

        def instance_ids(ids)
          @instance_ids += ids
          self
        end

        def tags(filter_hash = {})
          @filters += hash_to_tags_array(filter_hash)
          self
        end

        def filters(filters)
          @filters += filters
          self
        end

        def running
          @filters << { name: 'instance-state-name', values: ['running'] }
          self
        end

        def not_terminated
          @filters << { name: 'instance-state-name',
                        values: ['pending', 'running', 'shutting-down', 'stopping', 'stopped'] }
          self
        end

        def to_a
          fetch
        end
        alias :force :to_a
        alias :inspect :to_a

        private

        def hash_to_tags_array(hash)
          hash.map do |k, v|
            { name: "tag:#{k}", values: Array(v) }
          end
        end

        def fetch
          filter_param = @filters.empty? ? nil : @filters.uniq
          id_param = @instance_ids.empty? ? nil : @instance_ids.uniq
          @instances = @klass.client.describe_instances(instance_ids: id_param,
                                                        filters: filter_param).inject([]) do |all, page|
            all + page.reservations.map(&:instances).flatten.map do |ec2_instance|
              AwsRo::EC2::Instance.new(ec2_instance)
            end
          end
        end
      end
    end
  end
end
