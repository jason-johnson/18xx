# frozen_string_literal: true

require_relative '../base'
require_relative '../share_buying'
# require_relative 'share_buying_with_shorts'

module Engine
  module Step
    module G1828
      class PostMerger < Base
        include ShareBuying
        #        include ShareBuyingWithShorts

        def actions(entity)
          return [] if !entity.player? || !@round.converted

          actions = []
          actions << 'buy_shares' if can_buy_any?(entity)
          actions << 'sell_shares' if can_sell?(entity, nil)
          actions << 'pass' if actions.any?
          actions
        end

        def process_buy_shares(action)
          player = action.entity
          unshort = player.percent_of(corporation).negative?
          buy_shares(player, action.bundle)
          @game.unshort(player, action.bundle.shares[0]) if unshort

          player.pass! if !corporation.president?(player.owner) || !can_buy_any?(player)
        end

        def process_sell_shares(action)
          @game.sell_shares_and_change_price(action.bundle)
          action.entity.pass!
        end

        def description
          'Buy/Sell Shares Post Conversion'
        end

        def corporation
          @round.converted
        end

        def active?
          corporation
        end

        def active_entities
          return [] unless corporation
          # Ensure players can't buy after taking loans
          return [] unless corporation.share_price == @round.converted_price

          [@game.players.rotate(@game.players.index(corporation.owner))
          .select { |p| p.active? && (can_buy_any?(p) || can_sell?(p, nil)) }.first].compact
        end
      end
    end
  end
end
