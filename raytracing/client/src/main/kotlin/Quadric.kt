import vision.gears.webglmath.UniformProvider
import vision.gears.webglmath.Mat4
import vision.gears.webglmath.Vec1
import vision.gears.webglmath.Vec3

class Quadric(i : Int) : UniformProvider("""quadrics[${i}]""") {
  val surface by QuadraticMat4(unitSphere.clone())
  val clipper by QuadraticMat4(unitSlab.clone())
  val ideality by Vec3(0.0f, 0.0f, 0.0f)

  val diffuseCoeff by Vec3(0.2f, 0.3f, 0.3f)
  val specularCoeff by Vec3(0.0f, 0.0f, 0.0f)

  val powerDensity by Vec3(0.0f, 0.0f, 0.0f)
  val area by Vec1(0.0f)

  val absorb by Vec3(0.0f, 0.0f, 0.0f)

  companion object {
    val unitSphere = 
      Mat4(
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f
      )
    val unitSlab = 
      Mat4(
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f
      ) 
    val plane = 
      Mat4(
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -0.0f
      )            
  }

}