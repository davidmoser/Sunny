
class IrradianceViewer
  def onMouseMove(flags, x, y, view)
    ph = view.pick_helper
    ph.do_pick(x,y)
    entity = ph.best_picked
    if entity
      irradiance = entity.get_attribute 'solar_integration', 'total_irradiance'
      if irradiance
        view.tooltip = irradiance.to_s
      end
    else
      view.tooltip = ''
    end
  end
end


