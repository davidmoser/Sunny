
# a square has a @center, @irradiance information and the reference
# to its visual representation @face
class Tile
  attr_accessor :irradiance, :relative_irradiance, :face
  
  def initialize(group, center, side1, side2)
    @center = center
    corner = center + Geom::Vector3d.linear_combination(-0.5,side1,-0.5,side2)
    @face = group.entities.add_face([corner, corner+side1, corner+side1+side2, corner+side2])
    @face.edges.each{|e|e.hidden=true}
    @irradiance = 0
  end
end