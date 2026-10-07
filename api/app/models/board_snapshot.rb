class BoardSnapshot < ApplicationRecord
  def self.latest(upto_seq: nil)
    scope = order(seq: :desc)
    scope = scope.where(seq: ..upto_seq) if upto_seq
    scope.first
  end

  def self.prune!(keep:)
    where.not(id: order(seq: :desc).limit(keep).pluck(:id)).delete_all
  end
end
