class Intent < ApplicationRecord
  extend FriendlyId
  friendly_id :intentname, use: :history, slug_column: 'intentname'

  belongs_to :agent
  has_many :interpretations, dependent: :destroy

  serialize :locales, JSON

  validates :intentname, uniqueness: { scope: [:agent_id] }, length: { in: 3..25 }, presence: true
  validates :locales, presence: true
  validate :check_locales

  before_validation :clean_intentname
  before_validation :sort_locales
  before_create :set_position

  after_save do
    if saved_change_to_attribute?(:intentname)
      Nlp::Package.new(self.agent).push
    end
  end

  after_destroy do
    Nlp::Package.new(self.agent).push
  end

  def interpretations_with_local(locale)
    interpretations.where(locale: locale).order(created_at: :desc)
  end

  private

    def clean_intentname
      unless intentname.nil?
        self.intentname = intentname.parameterize(separator: '-')
      end
    end

    def check_locales
      if self.locales.present?
        for locale in self.locales
          if !Interpretation::Locales.include? locale
            errors.add(:locales, I18n.t('errors.intents.unknown_locale', current_locale: locale))
          end
        end
      end
    end

    def sort_locales
      self.locales.sort! if self.locales.respond_to?(:sort!)
    end

    def set_position
      unless agent.nil?
        self.position = agent.intents.maximum(:position) + 1
      end
    end
end
