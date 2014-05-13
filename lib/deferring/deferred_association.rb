# encoding: UTF-8

require 'delegate'

module Deferring
  class DeferredAssociation < SimpleDelegator

    attr_reader :load_state

    def initialize(original_association)
      super(original_association)
      @load_state = :ghost
    end

    alias_method :original_association, :__getobj__

    delegate :[], :size, :length,

             # SimpleDelegator
             :to_s,
             :to_a,
             :inspect,
             :==,

             # Enumerable + Array stuff
             # TODO: just take all methods from these modules?
             :map, :detect, :clear, # ...

             to: :objects

    # TODO: Add explanation about :first/:last loaded? problem.
    [:first, :last].each do |method|
      define_method method do
        unless objects_loaded?
          original_association.send(method)
        else
          objects.send(method)
        end
      end
    end

    # Rails 3.0 specific, not needed anymore for Rails 3.0+
    def set_inverse_instance(associated_record, parent_record)
      original_association.__send__(:set_inverse_instance, associated_record, parent_record)
    end

    def association
      load_objects
      original_association
    end

    def objects
      load_objects
      @objects
    end

    def original_objects
      load_objects
      @original_objects
    end

    def objects=(records)
      @objects = records
      @original_objects = original_association.to_a.clone
      objects_loaded!

      @objects
    end

    def ids
      objects.map(&:id)
    end

    def <<(records)
      # TODO: Do we want to prevent including the same object twice? Not sure,
      # but it will probably be filtered after saving and retrieving as well.
      objects.concat(Array(records).flatten)
    end
    alias_method :push, :<<
    alias_method :concat, :<<
    alias_method :append, :<<

    def delete(records)
      Array(records).flatten.uniq.each do |record|
        objects.delete(record)
      end
      self
    end

    def build(*args)
      association.build(args).tap do |result|
        objects.concat(result)
      end
    end

    def create!(*args)
      association.create!(args).tap do |result|
        objects.concat(result)
      end
    end

    def reload
      original_association.reload
      @load_state = :ghost
      self
    end
    alias_method :reset, :reload

    # Returns the associated records to which links will be created after saving
    # the parent of the association.
    def pending_creates
      objects - original_objects
    end
    alias_method :links, :pending_creates

    # Returns the associated records to which the links will be deleted after
    # saving the parent of the assocation.
    def pending_deletes
      original_objects - objects
    end
    alias_method :unlinks, :pending_deletes

    private

    def load_objects
      return if objects_loaded?

      @objects = original_association.to_a.clone
      @original_objects = @objects.clone.freeze
      objects_loaded!
    end

    def objects_loaded?
      @load_state == :loaded
    end

    def objects_loaded!
      @load_state = :loaded
    end

  end
end
