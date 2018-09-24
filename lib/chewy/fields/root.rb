module Chewy
  module Fields
    class Root < Chewy::Fields::Base
      attr_reader :dynamic_templates
      attr_reader :id
      attr_reader :parent
      attr_reader :parent_id
      attr_reader :routing
      attr_reader :routing_id

      def initialize(*args)
        super(*args)

        @id = @options.delete(:id) || options.delete(:_id)
        @parent = @options.delete(:parent) || options.delete(:_parent)
        @parent_id = @options.delete(:parent_id)
        @routing = @options.delete(:routing) || options.delete(:_routing) || {}
        @routing_id = @options.delete(:routing_id) || @routing.delete(:value)
        @value ||= -> { self }
        @dynamic_templates = []
        @options.delete(:type)
      end

      def mappings_hash
        mappings = super
        mappings[name].delete(:type)

        if dynamic_templates.present?
          mappings[name][:dynamic_templates] ||= []
          mappings[name][:dynamic_templates].concat dynamic_templates
        end

        mappings[name][:_parent] = parent.is_a?(Hash) ? parent : { type: parent } if parent
        mappings[name][:_routing] = routing if !routing.empty?
        mappings
      end

      def dynamic_template(*args)
        options = args.extract_options!.deep_symbolize_keys
        if args.first
          template_name = :"template_#{dynamic_templates.count.next}"
          template = {template_name => {mapping: options}}

          template[template_name][:match_mapping_type] = args.second.to_s if args.second.present?

          regexp = args.first.is_a?(Regexp)
          template[template_name][:match_pattern] = 'regexp' if regexp

          match = regexp ? args.first.source : args.first
          path = match.include?(regexp ? '\.' : '.')

          template[template_name][path ? :path_match : :match] = match
          @dynamic_templates.push(template)
        else
          @dynamic_templates.push(options)
        end
      end

      def compose_parent(object)
        return unless parent_id
        parent_id.arity.zero? ? object.instance_exec(&parent_id) : parent_id.call(object)
      end

      def compose_routing(object)
        return unless routing_id
        key = routing_id.arity.zero? ? object.instance_exec(&routing_id) : routing_id.call(object)
      end

      def compose_id(object)
        return unless id
        id.arity.zero? ? object.instance_exec(&id) : id.call(object)
      end

      # Converts passed object to JSON-ready hash. Used for objects import.
      #
      # @param object [Object] a base object for composition
      # @param crutches [Object] any object that will be passed to every field value proc as a last argument
      # @param fields [Array<Symbol>] a list of fields to compose, every field will be composed if empty
      # @return [Hash] JSON-ready heash with stringifyed keys
      def compose(object, crutches = nil, fields: [])
        result = evaluate([object, crutches])

        if children.present?
          child_fields = if fields.present?
            child_hash.slice(*fields).values
          else
            children
          end

          child_fields.each_with_object({}) do |field, memo|
            memo.merge!(field.compose(result, crutches) || {})
          end.as_json
        elsif fields.present?
          result.as_json(only: fields)
        else
          result.as_json
        end
      end

      # Children indexed by name as a hash.
      #
      # @return [Hash{Symbol => Chewy::Fields::Base}]
      def child_hash
        @child_hash ||= children.index_by(&:name)
      end
    end
  end
end
