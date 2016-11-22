require 'jsonapi/deserializable/resource_dsl'

module JSONAPI
  module Deserializable
    class Resource
      DEFAULT_TYPE_BLOCK = proc { |t| field type: t }
      DEFAULT_ID_BLOCK   = proc { |i| field id: i }
      DEFAULT_ATTR_BLOCK = proc { |k, v| field(k.to_sym => v) }
      DEFAULT_HAS_ONE_REL_BLOCK = proc do |k, _rel, id, type|
        field "#{k}_type".to_sym => type
        field "#{k}_id".to_sym   => id
      end
      DEFAULT_HAS_MANY_REL_BLOCK = proc do |k, _rel, ids, types|
        field "#{k}_types".to_sym => types
        field "#{k}_ids".to_sym   => ids
      end

      include ResourceDSL

      class << self
        attr_accessor :type_block, :id_block, :attr_blocks, :default_attr_block,
                      :has_one_rel_blocks, :has_many_rel_blocks,
                      :default_has_one_rel_block,
                      :default_has_many_rel_block
      end

      self.attr_blocks = {}
      self.has_one_rel_blocks  = {}
      self.has_many_rel_blocks = {}
      self.type_block = DEFAULT_TYPE_BLOCK
      self.id_block   = DEFAULT_ID_BLOCK
      self.default_attr_block         = DEFAULT_ATTR_BLOCK
      self.default_has_one_rel_block  = DEFAULT_HAS_ONE_REL_BLOCK
      self.default_has_many_rel_block = DEFAULT_HAS_MANY_REL_BLOCK

      def self.inherited(klass)
        super
        klass.type_block  = type_block
        klass.id_block    = id_block
        klass.attr_blocks         = attr_blocks.dup
        klass.has_one_rel_blocks  = has_one_rel_blocks.dup
        klass.has_many_rel_blocks = has_many_rel_blocks.dup
        klass.default_attr_block         = default_attr_block
        klass.default_has_one_rel_block  = default_has_one_rel_block
        klass.default_has_many_rel_block = default_has_many_rel_block
      end

      def self.call(payload)
        new(payload).to_h
      end

      def initialize(payload)
        @document = payload
        @data = @document['data']
        @type = @data['type']
        @id   = @data['id']
        @attributes    = @data['attributes'] || {}
        @relationships = @data['relationships'] || {}
        deserialize!
      end

      def to_hash
        @hash
      end
      alias to_h to_hash

      private

      def deserialize!
        @hash = {}
        deserialize_type!
        deserialize_id!
        deserialize_attrs!
        deserialize_rels!
      end

      def deserialize_type!
        instance_exec(@type, &self.class.type_block)
      end

      def deserialize_id!
        return unless @id
        instance_exec(@id, &self.class.id_block)
      end

      def deserialize_attrs!
        @attributes.each do |key, val|
          if self.class.attr_blocks.key?(key)
            instance_exec(val, &self.class.attr_blocks[key])
          else
            instance_exec(key, val, &self.class.default_attr_block)
          end
        end
      end

      def deserialize_rels!
        @relationships.each do |key, val|
          if val['data'].is_a?(Array)
            deserialize_has_many_rel!(key, val)
          else
            deserialize_has_one_rel!(key, val)
          end
        end
      end

      def deserialize_has_one_rel!(key, val)
        id   = val['data'] && val['data']['id']
        type = val['data'] && val['data']['type']
        if self.class.has_one_rel_blocks.key?(key)
          instance_exec(val, id, type, &self.class.has_one_rel_blocks[key])
        else
          instance_exec(key, val, id, type,
                        &self.class.default_has_one_rel_block)
        end
      end

      def deserialize_has_many_rel!(key, val)
        ids   = val['data'].map { |ri| ri['id'] }
        types = val['data'].map { |ri| ri['type'] }
        if self.class.has_many_rel_blocks.key?(key)
          instance_exec(val, ids, types, &self.class.has_many_rel_blocks[key])
        else
          instance_exec(key, val, ids, types,
                        &self.class.default_has_many_rel_block)
        end
      end

      def field(hash)
        @hash.merge!(hash)
      end
    end
  end
end
