
class IrradianceViewer
  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x,y)
    entity = ph.best_picked
    if entity
      irradiance = entity.get_attribute 'solar_integration', 'irradiance'
      if irradiance and irradiance!=@current_irradiance
        @current_irradiance = irradiance
        relative_irradiance = entity.get_attribute 'solar_integration', 'relative_irradiance'
        view.tooltip = "irradiance: #{irradiance}, relative: #{relative_irradiance}"
        @solar_integration.statistics.set_pointer_value( irradiance, relative_irradiance )
      end
    else
      view.tooltip = ''
    end
  end
end


