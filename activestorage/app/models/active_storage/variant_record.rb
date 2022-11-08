# frozen_string_literal: true

class ActiveStorage::VariantRecord < ActiveStorage::Record
  self.table_name = "active_storage_variant_records"

  alias_attribute :uuid, :id
  belongs_to :blob, primary_key: :uuid

  has_one_attached :image
end
