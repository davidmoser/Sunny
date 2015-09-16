require 'sketchup.rb'

class SolarIntegrationAppObserver < Sketchup::AppObserver
  def initialize(solar_integration)
    @solar_integration = solar_integration
  end

  def onOpenModel(model)
    update_from_model
  end

  def onActivateModel(model)
    update_from_model
  end
  
  def onNewModel(model)
    update_from_model
  end

  def update_from_model
    @solar_integration.configuration.update_from_model
    @solar_integration.statistics.update_from_model
    @solar_integration.sun_data.update_from_model
  end
end