
class Menu
  def initialize(solar_integration)
    @solar_integration = solar_integration
    
    @menu = UI.menu.add_submenu('Solar Integration')
    
    add_faces_menu('Integrate selection', :integrate)
    
    add_menu('Irradiance Viewer') do
      Sketchup.active_model.select_tool IrradianceViewer.new
    end

    add_menu('Configuration ...') do
      solar_integration.update_configuration
    end
    
    add_menu('Nice configuration ...') do
      dialog = UI::WebDialog.new('Nice configuration', true, 'solar_integration_configuration', 400, 400, 150, 150, true)

      pathname = File.expand_path( File.dirname(__FILE__) )
      pathname = File.join( pathname, 'configuration.html' )
      dialog.set_file( pathname )

      dialog.show
    end
    
    @menu.add_separator
    
    add_faces_menu('Visualize spherical hash map', :visualize_hash_map)
    add_faces_menu('Visualize sun states', :visualize_sun_states)
    add_faces_menu('Visualize shadow pyramids', :visualize_shadow_pyramids)
  end
  
  def add_menu(name)
    @menu.add_item(name) { yield }
  end
  
  def add_faces_menu(name, method)
    add_menu(name) do
      selection = Sketchup.active_model.selection
      faces = selection.select{|f|f.typename=='Face'}
      faces.each do |f|
        @solar_integration.send(method, f)
      end
    end
  end
end
