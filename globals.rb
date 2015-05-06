
def to_radian(degree)
  return degree * Math::PI / 180
end

def to_degree(radian)
  return radian * 180 / Math::PI
end

X_AXIS = Geom::Vector3d.new(1,0,0)
Y_AXIS = Geom::Vector3d.new(0,1,0)
Z_AXIS = Geom::Vector3d.new(0,0,1)
ORIGIN = Geom::Point3d.new(0,0,0)
ECLIPTIC_ANGLE = 23.4

# sun_transformation transforms solar north to z axis
# in that coordinate system the suns inclination lies between +-ECLIPTIC_ANGLE
si = Sketchup.active_model.shadow_info
sun_angle = to_radian(90 - si['Latitude'])
north_angle = to_radian(si['NorthAngle'])
SUN_TRANSFORMATION = Geom::Transformation.rotation(ORIGIN, X_AXIS, sun_angle) \
                    * Geom::Transformation.rotation(ORIGIN, Z_AXIS, north_angle)
                  
INSTALLATION_FOLDER = 'Plugins/solar_integration'