require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord

  belongs_to :projekt, optional: true
  has_one :proposal_phase, through: :projekt
  has_many :geozone_restrictions, through: :proposal_phase
  has_many :geozone_affiliations, through: :projekt

  validates :projekt_id, presence: true, if: :require_a_projekt?
  validate :description_sanitized

  def require_a_projekt?
    Setting["projekts.connected_resources"].present? ? true : false
  end

  def votable_by?(user)
      user &&
      !user.organization? &&
      user.level_two_or_three_verified? &&
      (
        Setting['feature.user.skip_verification'].present? ||
        projekt.blank? ||
        proposal_phase && proposal_phase.geozones.blank? ||
        (proposal_phase && proposal_phase.geozones.any? && proposal_phase.geozones.include?(user.geozone) )
      ) &&
      (
        projekt.blank? ||
        proposal_phase && !proposal_phase.expired?
      )
  end

  def description_sanitized
    sanitized_description = ActionController::Base.helpers.strip_tags(description)
    errors.add(:description, :too_long, message: 'too long text') if
      sanitized_description.length > Setting[ "extended_option.description_max_length"].to_i
  end
end
