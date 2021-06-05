require 'pstore'

class PowStore
  attr_reader :store

  def initialize(store=__dir__ + "/../pows.pstore")
    @store = PStore.new(store)
    @store.ultra_safe = true
  end

  def new(key:, wanted:)
    @store.transaction do
      @store[key] = {
        wanted: wanted,
        solved: false
      }
      @store.commit
    end
  end

  def solved(key)
    @store.transaction do
      @store[key][:solved] = true
      @store.commit
    end
  end

  def delete(key)
    @store.transaction do
      @store.delete(key)
      @store.commit
    end
  end

  def [](key)
    @store.transaction(true) do
      @store[key]
    end
  end 
end
