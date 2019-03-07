require 'net/http'
include ActiveSupport::Benchmarkable

class Nlp::Package
  # Used to disable nlp sync if necessary via
  # Nlp::Package.sync_active = false
  class_attribute :sync_active
  self.sync_active = true

  JSON_HEADERS = {"Content-Type" => "application/json", "Accept" => "application/json"}

  REDIS_URL = ENV.fetch("VIKYAPP_REDIS_PACKAGE_NOTIFIER") { 'redis://localhost:6379/3' }

  def initialize(agent)
    @agent = agent
  end

  def self.reinit
    return if Rails.env.test?
    unless Nlp::Package.sync_active
      Rails.logger.info '  Skipping push_all packages to NLP because sync is deactivated'
      return
    end
    event = :reinit
    redis_opts = {
      url: REDIS_URL
    }
    redis = Redis.new(redis_opts)
    redis.publish(:viky_packages_change_notifications, { event: event }.to_json)
    Rails.logger.info "  | Redis notify agent's #{event}"
  end

  def destroy
    return if Rails.env.test?
    unless Nlp::Package.sync_active
      Rails.logger.info "  Skipping destroy of package #{@agent.id} to NLP because sync is deactivated"
      return
    end
    notify(:delete)
  end

  def push
    return if Rails.env.test?
    unless Nlp::Package.sync_active
      Rails.logger.info "  Skipping push of package #{@agent.id} to NLP because sync is deactivated"
      return
    end
    notify(:update)
  end

  def generate_json
    JSON.parse(
      ApplicationController.render(
        template: 'agents/package',
        assigns: { agent: @agent, interpretations: build_tree },
        format: :json
      )
    )
  end

  def full_json_export
    packages_list = full_packages_map(@agent).values
    packages_list.collect do |package|
      Nlp::Package.new(package).generate_json
    end
  end

  def logger
    Rails.logger
  end


  private

    def notify event
      redis_opts = {
        url: REDIS_URL
      }
      redis = Redis.new(redis_opts)
      redis.publish(:viky_packages_change_notifications, { event: event, id: @agent.id }.to_json  )
      Rails.logger.info "  | Redis notify agent's #{event} #{@agent.id}"
    end

    def full_packages_map(agent)
      return { agent.id => agent } if agent.successors.nil?
      result = { agent.id => agent }
      agent.successors.each do |successor|
        result.merge! full_packages_map(successor)
      end
      result
    end

    def build_tree
      interpretations = []
      slug = @agent.slug
      @agent.intents.order(position: :desc).each do |intent|
        cache_key = ['pkg', slug, 'intent', intent.id, (intent.updated_at.to_f * 1000).to_i].join('/')
        interpretations += Rails.cache.fetch("#{cache_key}/build_internals_list_nodes") do
          build_internals_list_nodes(intent)
        end
        interpretations << Rails.cache.fetch("#{cache_key}/build_node"){ build_intent(intent) }
      end
      @agent.entities_lists.order(position: :desc).each do |elist|
        cache_key = ['pkg', slug, 'entities_list', elist.id, (elist.updated_at.to_f * 1000).to_i].join('/')
        interpretations += Rails.cache.fetch("#{cache_key}/build_internals_list_nodes") do
          build_internals_list_nodes(elist)
        end
        interpretations << Rails.cache.fetch("#{cache_key}/build_node"){ build_entities_list(elist) }
      end
      interpretations
    end

    def build_internals_list_nodes(intent)
      interpretations = []

      InterpretationAlias
        .includes(:interpretation)
        .where(is_list: true, interpretations: { intent_id: intent.id }).order('interpretations.position DESC, interpretations.locale ASC').order(:position_start).each do |ialias|

        interpretation_hash = {}
        interpretation_hash[:id]   = "#{ialias.interpretation_aliasable.id}_#{ialias.id}_recursive"
        interpretation_hash[:slug] = "#{ialias.interpretation_aliasable.slug}_#{ialias.id}_recursive"
        interpretation_hash[:scope] = 'hidden'

        expressions = []

        expression = {}
        expression[:expression] = "@{#{ialias.aliasname}}"
        expression[:id] = ialias.interpretation.id
        expression[:aliases] = []
        expression[:aliases] << build_internal_alias(ialias)
        expression[:keep_order] = ialias.interpretation.keep_order if ialias.interpretation.keep_order
        expression[:glue_distance] = ialias.interpretation.proximity.get_distance
        expressions << expression

        expression = {}
        expression[:expression] = "@{#{ialias.aliasname}} @{#{ialias.aliasname}_recursive}"
        expression[:id] = ialias.interpretation.id
        expression[:aliases] = []
        expression[:aliases] << build_internal_alias(ialias)
        expression[:aliases] << build_internal_alias(ialias, true)
        expression[:keep_order] = ialias.interpretation.keep_order if ialias.interpretation.keep_order
        expression[:glue_distance] = ialias.interpretation.proximity.get_distance
        expressions << expression

        if ialias.any_enabled
          expression = {}
          expression[:expression] = "@{#{ialias.aliasname}} @{#{ialias.aliasname}_recursive}"
          expression[:id] = ialias.interpretation.id
          expression[:aliases] = []
          expression[:aliases] << {
            alias: ialias.aliasname,
            type: 'any'
          }
          expression[:aliases] << build_internal_alias(ialias, true)
          expression[:keep_order] = ialias.interpretation.keep_order if ialias.interpretation.keep_order
          expression[:glue_distance] = ialias.interpretation.proximity.get_distance
          expressions << expression
        end

        interpretation_hash[:expressions] = expressions
        interpretations << interpretation_hash
      end
      interpretations

    end

    def build_intent(intent)
      interpretation_hash = {}
      interpretation_hash[:id] = intent.id
      interpretation_hash[:slug] = intent.slug
      interpretation_hash[:scope] = intent.is_public? ? 'public' : 'private'
      expressions = []

      intent.interpretations.order(position: :desc, locale: :asc).each do |interpretation|
        expression = {}
        expression[:expression] = interpretation.expression_with_aliases
        expression[:id]         = interpretation.id
        expression[:aliases]    = build_aliases(interpretation)
        expression[:locale]     = interpretation.locale     unless interpretation.locale == Locales::ANY
        expression[:keep_order] = interpretation.keep_order if interpretation.keep_order
        expression[:glue_distance] = interpretation.proximity.get_distance
        expression[:solution]   = build_interpretation_solution(interpretation)
        expressions << expression

        interpretation.interpretation_aliases
          .where(any_enabled: true, is_list: false)
          .order(position_start: :asc).each do |ialias|
          expressions << build_any_node(ialias, expression)
        end
      end
      interpretation_hash[:expressions] = expressions
      interpretation_hash
    end

    def build_entities_list(elist)
      interpretation_hash = {}
      interpretation_hash[:id] = elist.id
      interpretation_hash[:slug] = elist.slug
      interpretation_hash[:scope] = elist.is_public? ? 'public' : 'private'
      expressions = []

      elist.entities.find_each do |entity|
        entity.terms.each do |term|
          expression = {}
          expression[:expression] = term['term']
          expression[:id] = entity.id
          expression[:locale] = term['locale'] unless term['locale'] == Locales::ANY
          expression[:solution] = build_entities_list_solution(entity)
          expression[:keep_order] = true
          expression[:glue_distance] = elist.proximity.get_distance
          expression[:glue_strength] = 'punctuation' if elist.proximity_glued?
          expressions << expression
        end
      end
      interpretation_hash[:expressions] = expressions
      interpretation_hash
    end

    def build_any_node(ialias, expression)
      any_aliasname = ialias.aliasname
      any_expression = expression.deep_dup
      old_aliases = expression[:aliases]
      any_expression[:aliases] = []
      old_aliases.each do |jsonalias|
        if jsonalias[:alias] == any_aliasname
          any_expression[:aliases] << {
            alias: any_aliasname,
            type: 'any'
          }
        else
          any_expression[:aliases] << jsonalias
        end
      end
      any_expression
    end

    def build_internal_alias(ialias, recursive=false)
      if recursive
        {
          alias: "#{ialias.aliasname}_recursive",
          slug: "#{ialias.interpretation_aliasable.slug}_#{ialias.id}_recursive",
          id: "#{ialias.interpretation_aliasable.id}_#{ialias.id}_recursive",
          package: @agent.id
        }
      else
        {
          alias: ialias.aliasname,
          slug: ialias.interpretation_aliasable.slug,
          id: ialias.interpretation_aliasable.id,
          package: @agent.id
        }
      end
    end

    def build_aliases(interpretation)
      interpretation.interpretation_aliases
        .order(:position_start)
        .collect { |ialias| build_alias(ialias) }
    end

    def build_alias(ialias)
      result = {
        alias: ialias.aliasname
      }
      if ialias.type_number?
        result[:type] = 'number'
      elsif ialias.type_regex?
        result[:type] = 'regex'
        result[:regex] = ialias.reg_exp
      else
        result[:package] = @agent.id
        if ialias.is_list
          result[:slug] = "#{ialias.interpretation_aliasable.slug}_#{ialias.id}_recursive"
          result[:id] = "#{ialias.interpretation_aliasable.id}_#{ialias.id}_recursive"
        else
          result[:slug] = ialias.interpretation_aliasable.slug
          result[:id] = ialias.interpretation_aliasable.id
        end
      end
      result
    end

    def build_interpretation_solution(interpretation)
      result = ''
      if interpretation.auto_solution_enabled
        if interpretation.interpretation_aliases.empty?
          result = interpretation.expression
        end
      else
        result = "`#{interpretation.solution}`" unless interpretation.solution.blank?
      end
      result
    end

    def build_entities_list_solution(entity)
      result = ''
      if entity.auto_solution_enabled
        result = entity.terms.first['term']
      else
        result = "`#{entity.solution}`" unless entity.solution.blank?
      end
      result
    end
end
