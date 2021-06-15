require_dependency Rails.root.join("app", "controllers", "debates_controller").to_s

class DebatesController < ApplicationController
  include ImageAttributes

  before_action :load_categories, only: [:index, :new, :create, :edit, :map, :summary]
  before_action :process_tags, only: [:create, :update]

  def index_customization
    @filtered_goals = params[:sdg_goals].present? ? params[:sdg_goals].split(',').map{ |code| code.to_i } : nil
    @filtered_target = params[:sdg_targets].present? ? params[:sdg_targets].split(',')[0] : nil

    @geozones = Geozone.all

    @selected_geozone_affiliation = params[:geozone_affiliation] || 'no_affiliation'
    @affiliated_geozones = (params[:affiliated_geozones] || '').split(',').map(&:to_i)

    @selected_geozone_restriction = params[:geozone_restriction] || 'no_restriction'
    @restricted_geozones = (params[:restricted_geozones] || '').split(',').map(&:to_i)

    @featured_debates = @debates.featured
    take_only_by_tag_names
    take_by_projekts
    take_by_sdgs
    take_by_geozone_affiliations
    take_by_geozone_restrictions
    @selected_tags = all_selected_tags
  end

  def show
    super

    @projekt = @debate.projekt

    @related_contents = Kaminari.paginate_array(@debate.relationed_contents).page(params[:page]).per(5)
    redirect_to debate_path(@debate), status: :moved_permanently if request.path != debate_path(@debate)
  end

  private

  def debate_params
    attributes = [:tag_list, :terms_of_service, :projekt_id, :related_sdg_list,
                  image_attributes: image_attributes]
    params.require(:debate).permit(attributes, translation_params(Debate))
  end

  def process_tags
    if params[:debate][:tags]
      params[:tags] = params[:debate][:tags].split(',')
      params[:debate].delete(:tags)
    end
    params[:debate][:tag_list_custom]&.split(",")&.each do |t|
      next if t.strip.blank?
      Tag.find_or_create_by name: t.strip
    end
    params[:debate][:tag_list] ||= ""
    params[:debate][:tag_list] += ((params[:debate][:tag_list_predefined] || "").split(",") + (params[:debate][:tag_list_custom] || "").split(",")).join(",")
    params[:debate].delete(:tag_list_predefined)
    params[:debate].delete(:tag_list_custom)
  end

  def take_only_by_tag_names
    if params[:tags].present?
      @resources = @resources.tagged_with(params[:tags].split(","), all: true, any: :true)
    end
  end

  def take_by_projekts
    if params[:projekts].present?
      @resources = @resources.where(projekt_id: params[:projekts].split(',')).distinct
    end
  end

  def take_by_sdgs
    if params[:sdg_targets].present?
      @resources = @resources.joins(:sdg_global_targets).where(sdg_targets: { code: params[:sdg_targets].split(',')[0] }).distinct
      return
    end

    if params[:sdg_goals].present?
      @resources = @resources.joins(:sdg_goals).where(sdg_goals: { code: params[:sdg_goals].split(',') }).distinct
    end
  end

  def take_by_geozone_affiliations
    case @selected_geozone_affiliation
    when 'all_resources'
      @resources
    when 'no_affiliation'
      @resources = @resources.joins(:projekt).where( projekts: { geozone_affiliated: 'no_affiliation' } ).distinct
    when 'entire_city'
      @resources = @resources.joins(:projekt).where(projekts: { geozone_affiliated: 'entire_city' } ).distinct
    when 'only_geozones'
      @resources = @resources.joins(:projekt).where(projekts: { geozone_affiliated: 'only_geozones' } ).distinct
      if @affiliated_geozones.present?
        @resources = @resources.joins(:geozone_affiliations).where(geozones: { id: @affiliated_geozones }).distinct
      else
        @resources = @resources.joins(:geozone_affiliations).where.not(geozones: { id: nil }).distinct
      end
    end
  end

  def take_by_geozone_restrictions
    case @selected_geozone_restriction
    when 'no_restriction'
      @resources = @resources.joins(:debate_phase).where( projekt_phases: { geozone_restricted: ['no_restriction', 'only_citizens', 'only_geozones'] } ).distinct
    when 'only_citizens'
      @resources = @resources.joins(:debate_phase).where(projekt_phases: { geozone_restricted: ['only_citizens', 'only_geozones'] }).distinct
    when 'only_geozones'
      @resources = @resources.joins(:debate_phase).where(projekt_phases: { geozone_restricted: 'only_geozones' }).distinct
      if @restricted_geozones.present?
        @resources = @resources.joins(:geozone_restrictions).where(geozones: { id: @restricted_geozones }).distinct
      else
        @resources = @resources.joins(:geozone_restrictions).where.not(geozones: { id: nil }).distinct
      end
    end
  end
end
