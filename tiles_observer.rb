require 'sketchup.rb'

class TilesObserver < Sketchup::EntityObserver
  def onEraseEntity(entity)
    $solar_integration.statistics.update_values
  end

  def onElementModified(entities, entity)
    $solar_integration.statistics.update_values
  end
end