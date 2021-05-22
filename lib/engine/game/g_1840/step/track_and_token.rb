# frozen_string_literal: true

require_relative '../../../step/track_and_token'

module Engine
  module Game
    module G1840
      module Step
        class TrackAndToken < Engine::Step::TrackAndToken
          def process_place_token(action)
            entity = action.entity
            city = action.city
            token = city.tokens[action.slot]
            hex = city.hex

            if token&.corporation&.type == :city
              check_connected(entity, city, hex)
              spender = @game.owning_major_corporation(entity)
              spender.spend(40, @game.bank)
              @log << "#{entity.name} removes token from #{hex.name} (#{hex.location_name}) "\
                      "for #{@game.format_currency(40)}"
              token.destroy!
            end

            spender = @game.owning_major_corporation(entity)
            place_token(entity, city, action.token, spender: spender)

            @game.city_graph.clear
            @tokened = true
            pass! unless can_lay_tile?(entity)
          end

          def process_lay_tile(action)
            entity = action.entity
            spender = @game.owning_major_corporation(entity)
            tile = action.tile

            lay_tile_action(action, spender: spender)
            pass! if !can_lay_tile?(entity) && @tokened

            if @game.orange_framed?(tile)
              @orange_placed = true
              if tile.color == 'yellow'
                type = read_type_from_icon(action.hex)

                if type == 'token'
                  @round.pending_special_tokens << {
                    entity: entity,
                    token: entity.find_token_by_type,
                  }
                else
                  @round.pending_tile_lays << {
                    entity: entity,
                    color: type,
                  }
                end

              end
            end
            @normal_placed = true unless @game.orange_framed?(tile)
          end

          def available_hex(entity, hex)
            return @game.graph.reachable_hexes(entity)[hex] unless can_lay_tile?(entity, hex)
            return !@orange_placed if @game.orange_framed?(hex.tile)
            return @game.graph.connected_nodes(entity)[hex] if @normal_placed

            super
          end

          def setup
            super
            @orange_placed = false
            @normal_placed = false
          end

          def potential_tiles(_entity, hex)
            tiles = super

            return tiles.select { |tile| @game.orange_framed?(tile) } if @game.orange_framed?(hex.tile)

            tiles.reject { |tile| @game.orange_framed?(tile) }
          end

          def legal_tile_rotation?(_entity, hex, tile)
            if @game.orange_framed?(hex.tile) && tile.color == :yellow
              needed_exits = @game.needed_exits_for_hex(hex)
              return (tile.exits & needed_exits).size == needed_exits.size
            end

            super
          end

          def read_type_from_icon(hex)
            name = hex.original_tile.icons.first.name
            name.split('_').first
          end

          def show_other
            @game.owning_major_corporation(current_entity)
          end

          def can_replace_token?(_entity, _token)
            true
          end

          def can_place_token?(entity)
            current_entity == entity &&
              !@round.tokened &&
              !(tokens = available_tokens(entity)).empty? &&
              min_token_price(tokens) <= buying_power(entity)
          end
        end
      end
    end
  end
end
