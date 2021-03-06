module Rankers
  class ShipsRanker
    attr_reader :ships, :number_of_tournaments, :number_of_squadrons

    def initialize(ranking_configuration, ship_id: nil, ship_combo_id: nil, group_by_faction: false, faction_id: nil)
      start_date      = ranking_configuration[:ranking_start]
      end_date        = ranking_configuration[:ranking_end]
      tournament_type = ranking_configuration[:tournament_type]
      game_format = ranking_configuration[:format_id]
      joins = <<-SQL
        inner join pilots
          on ships.id = pilots.ship_id
        inner join factions
          on pilots.faction_id = factions.id
        inner join ship_configurations
          on ship_configurations.pilot_id = pilots.id
        inner join squadrons
          on ship_configurations.squadron_id = squadrons.id
        inner join tournaments
          on squadrons.tournament_id = tournaments.id
      SQL
      weight_query_builder = WeightQueryBuilder.new(ranking_configuration)
      attributes           = {
        id: 'ships.id',
        xws: 'ships.xws',
        name: 'ships.name',
        weight: weight_query_builder.build_weight_query,
        font_icon_class: 'ships.icon',
        squadrons: 'count(distinct squadrons.id)',
        tournaments: 'count(distinct tournaments.id)',
        average_percentile: weight_query_builder.build_average_query,
        average_wlr: weight_query_builder.build_win_loss_query,
      }
      ships_relation = Ship
                       .joins(joins)
                       .group('ships.id, ships.name')
                       .order('weight desc')
                       .where('tournaments.date >= ? and tournaments.date <= ?', start_date, end_date)
      if group_by_faction
        ships_relation            = ships_relation.group('factions.id, factions.name')
        attributes[:faction_id]   = 'factions.id'
        attributes[:faction_name] = 'factions.name'
      end

      ships_relation = ships_relation.where('factions.id = ?', faction_id) if faction_id.present?
      ships_relation = ships_relation.where('ships.id = ?', ship_id) if ship_id.present?
      ships_relation = ships_relation.where('squadrons.ship_combo_id = ?', ship_combo_id) if ship_combo_id.present?
      ships_relation = ships_relation.where('tournaments.tournament_type_id = ?', tournament_type) if tournament_type.present?
      ships_relation = ships_relation.where('tournaments.format_id = ?', game_format) if game_format.present?

      @ships = Ship.fetch_query(ships_relation, attributes)
      @pilots = Pilot.all.includes(:faction).to_a

      @number_of_tournaments, @number_of_squadrons = Rankers::GenericRanker.new(start_date, end_date, tournament_type, game_format).numbers
    end

    def ship_pilots
      @pilots.group_by(&:ship_id)
    end
  end
end
