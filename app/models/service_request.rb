class ServiceRequest < ApplicationRecord
  CATEGORIES = %w[financial_planning profile_update document_question general].freeze
  PRIORITIES = %w[normal high].freeze
  TRANSITIONS = {
    "open" => %w[in_progress cancelled],
    "in_progress" => %w[resolved cancelled],
    "resolved" => [],
    "cancelled" => []
  }.freeze

  belongs_to :client

  validates :subject, presence: true, length: { maximum: 160 }
  validates :description, presence: true, length: { maximum: 4000 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: TRANSITIONS.keys }
  validates :resolution_summary, length: { maximum: 2000 }
  validates :resolution_summary, presence: true, if: -> { status == "resolved" }
  validate :valid_transition
  validate :resolution_only_when_resolved

  before_save :stamp_resolution

  private

  def valid_transition
    if new_record?
      errors.add(:status, "must start as open") unless status == "open"
    elsif will_save_change_to_status? && !TRANSITIONS.fetch(status_in_database, []).include?(status)
      errors.add(:status, "cannot transition from #{status_in_database} to #{status}")
    end
  end

  def resolution_only_when_resolved
    if status != "resolved" && resolution_summary.present?
      errors.add(:resolution_summary, "is only allowed when resolving a request")
    end
  end

  def stamp_resolution
    self.resolved_at = Time.current if will_save_change_to_status? && status == "resolved"
  end
end
