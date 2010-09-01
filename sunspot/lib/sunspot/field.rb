module Sunspot
  class Field #:nodoc:
    attr_accessor :name # The public-facing name of the field
    attr_accessor :type # The Type of the field
    attr_accessor :reference # Model class that the value of this field refers to
    attr_reader :boost
    attr_reader :indexed_name # Name with which this field is indexed internally. Based on public name and type or the +:as+ option.

    # 
    #
    def initialize(name, type, options = {}) #:nodoc
      @name, @type = name.to_sym, type
      @stored = !!options.delete(:stored)
      @more_like_this = !!options.delete(:more_like_this)
      @indexed_name = (options.delete(:as) || @type.indexed_name(@name)).to_s
      raise ArgumentError, "Field of type #{type} cannot be used for more_like_this" unless type.accepts_more_like_this? or !@more_like_this
    end

    # Convert a value to its representation for Solr indexing. This delegates
    # to the #to_indexed method on the field's type.
    #
    # ==== Parameters
    #
    # value<Object>:: Value to convert to Solr representation
    #
    # ==== Returns
    #
    # String:: Solr representation of the object
    #
    # ==== Raises
    #
    # ArgumentError::
    #   the value is an array, but this field does not allow multiple values
    #
    def to_indexed(value)
      if value.is_a? Array
        if @multiple
          value.map { |val| to_indexed(val) }
        else
          raise ArgumentError, "#{name} is not a multiple-value field, so it cannot index values #{value.inspect}"
        end
      else
        @type.to_indexed(value)
      end
    end

    # Cast the value into the appropriate Ruby class for the field's type
    #
    # ==== Parameters
    #
    # value<String>:: Solr's representation of the value
    #
    # ==== Returns
    #
    # Object:: The cast value
    #
    def cast(value)
      @type.cast(value)
    end

    # 
    # Whether this field accepts multiple values.
    #
    # ==== Returns
    #
    # Boolean:: True if this field accepts multiple values.
    #
    def multiple?
      !!@multiple
    end

    # 
    # Whether this field can be used for more_like_this queries.
    # If true, the field is configured to store termVectors.
    #
    # ==== Returns
    #
    # Boolean:: True if this field can be used for more_like_this queries.
    #
    def more_like_this?
      !!@more_like_this
    end

    #
    # Whether this field is stored.
    #
    # ==== Returns
    #
    # Boolean:: True if this field is stored.
    #
    def stored?
      @stored
    end

    def hash
      indexed_name.hash
    end

    def eql?(field)
      indexed_name == field.indexed_name
    end
    alias_method :==, :eql?
  end

  # 
  # FulltextField instances represent fields that are indexed as fulltext.
  # These fields are tokenized in the index, and can have boost applied to
  # them. They also always allow multiple values (since the only downside of
  # allowing multiple values is that it prevents the field from being sortable,
  # and sorting on tokenized fields is nonsensical anyway, there is no reason
  # to do otherwise). FulltextField instances always have the type TextType.
  #
  class FulltextField < Field #:nodoc:
    attr_reader :default_boost

    def initialize(name, options = {})
      super(name, Type::TextType.instance, options)
      @multiple = true
      @boost = options.delete(:boost)
      @default_boost = options.delete(:default_boost)
      raise ArgumentError, "Unknown field option #{options.keys.first.inspect} provided for field #{name.inspect}" unless options.empty?
    end

    def indexed_name
      "#{super}#{'s' if @stored}#{'v' if more_like_this?}"
    end
  end

  # 
  # AttributeField instances encapsulate non-tokenized attribute data.
  # AttributeFields can have any type except TextType, and can also have
  # a reference (for instantiated facets), optionally allow multiple values
  # (false by default), and can store their values (false by default). All
  # scoping, sorting, and faceting is done with attribute fields.
  #
  class AttributeField < Field #:nodoc:
    def initialize(name, type, options = {})
      super(name, type, options)
      @multiple = !!options.delete(:multiple)
      @reference =
        if (reference = options.delete(:references)).respond_to?(:name)
          reference.name
        elsif reference.respond_to?(:to_sym)
          reference.to_sym
        end
      raise ArgumentError, "Unknown field option #{options.keys.first.inspect} provided for field #{name.inspect}" unless options.empty?
    end

    # The name of the field as it is indexed in Solr. The indexed name
    # contains a suffix that contains information about the type as well as
    # whether the field allows multiple values for a document.
    #
    # ==== Returns
    #
    # String:: The field's indexed name
    #
    def indexed_name
      "#{super}#{'m' if @multiple}#{'s' if @stored}#{'v' if more_like_this?}"
    end
  end

  class TypeField #:nodoc:
    class <<self
      def alias(dest_class, source_class_name)
        @@inverted = nil # invalidate cache
        aliases[dest_class] = source_class_name
      end

      def aliases
        @@aliases ||= {}
      end

      def aliases_inverted
        @@inverted ||= aliases.invert
      end

      def instance
        @instance ||= new
      end
    end

    def indexed_name
      'type'
    end

    def to_indexed(clazz)
      self.class.aliases[clazz] || clazz.name
    end
  end

  class IdField #:nodoc:
    class <<self
      def instance
        @instance ||= new
      end
    end

    def indexed_name
      'id'
    end

    def to_indexed(id)
      id.to_s
    end
  end
end
