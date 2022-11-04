# frozen_string_literal: true

class ActiveStorage::VariantRecord < ActiveStorage::Record
  self.table_name = "active_storage_variant_records"

  alias_method :uuid, :id

  belongs_to :blob
  has_one_attached :image
end
