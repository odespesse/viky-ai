class Intent < ApplicationRecord
  extend FriendlyId
  friendly_id :intentname, use: :history, slug_column: 'intentname'

  belongs_to :agent

  validates :intentname, uniqueness: { scope: [:agent_id] }, length: { in: 3..25 }, presence: true

  before_validation :clean_intentname

  private

  def clean_intentname
    unless intentname.nil?
      self.intentname = intentname.parameterize(separator: '-')
    end
  end
end