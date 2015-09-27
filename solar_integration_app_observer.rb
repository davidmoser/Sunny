require 'sketchup.rb'

class SolarIntegrationAppObserver < Sketchup::AppObserver
  def initialize(solar_integration)
    @solar_integration = solar_integration
  end

  def onOpenModel(model)
    update
  end

  def onActivateModel(model)
    update
  end
  
  def onNewModel(model)
    update
  end

  def update
    @solar_integration.configuration.update
    @solar_integration.statistics.update
  end
end