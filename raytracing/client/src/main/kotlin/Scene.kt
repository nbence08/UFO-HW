import org.w3c.dom.HTMLCanvasElement
import org.khronos.webgl.WebGLRenderingContext as GL
import vision.gears.webglmath.UniformProvider
import vision.gears.webglmath.*
import org.khronos.webgl.Uint32Array
import org.khronos.webgl.get
import kotlin.js.Date
import kotlin.math.sin
import kotlin.math.cos

class Scene (
  val gl : WebGL2RenderingContext) : UniformProvider("scene"){

  val vsQuad = Shader(gl, GL.VERTEX_SHADER, "quad-vs.glsl")
  val fsTrace = Shader(gl, GL.FRAGMENT_SHADER, "trace-fs.glsl")  
  val fsShow = Shader(gl, GL.FRAGMENT_SHADER, "show-fs.glsl")    
  val traceProgram = Program(gl, vsQuad, fsTrace, Program.PNT)
  val showProgram = Program(gl, vsQuad, fsShow, Program.PNT)  
  val quadGeometry = TexturedQuadGeometry(gl)  

  val timeAtFirstFrame = Date().getTime()
  var timeAtLastFrame =  timeAtFirstFrame

  val camera = PerspectiveCamera(*Program.all)

  val quadrics = ArrayList<Quadric>()
  val lights = ArrayList<Light>()

  val envTexture by SamplerCube()

  val randoms by Vec4Array(64)
  val lightRandoms by Vec3Array(100)

  lateinit var defaultFramebuffer : DefaultFramebuffer  
  lateinit var framebuffers : Pair<Framebuffer, Framebuffer>

  val previousFrameTexture by Sampler2D()
  val averagedFrameTexture by Sampler2D()

  val iFrame by Vec1()

  val x0 = -18.0f
  val y0 = 8.0f

  init {
    addComponentsAndGatherUniforms(*Program.all)
    quadrics.add(Quadric(0))
    quadrics.add(Quadric(1))
    quadrics.add(Quadric(2))
    quadrics.add(Quadric(3))
    quadrics.add(Quadric(4))
    quadrics.add(Quadric(5))
    quadrics.add(Quadric(6))
    quadrics[0].surface.transform(
      Mat4().translate(5.0f, 1.0f)
      )    
    quadrics[0].clipper.transform(
      Mat4().translate(5.0f, 1.0f)
      )
    quadrics[0].ideality.set(Vec3(1.0f, 1.0f, 1.0f))
    quadrics[0].specularCoeff.set(Vec3(1.0f, 1.0f, 1.0f))

    quadrics[1].surface.set(Quadric.plane)
    quadrics[1].clipper.set(Quadric.unitSphere)
    quadrics[1].clipper.transform(
      Mat4().scale(10f, 10f, 10f))

    quadrics[2].surface.set(Quadric.plane)
    quadrics[2].clipper.set(Quadric.unitSphere)
    quadrics[2].clipper.transform(
      Mat4().scale(10f, 10f, 10f).translate(0f, 13f, 0f))    
    quadrics[2].surface.transform(
      Mat4().translate(0f, 13f, 0f))

    quadrics[3].surface.set(Mat4(
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f
      ))
    quadrics[3].clipper.set(Mat4(
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -1.0f
      ))
    quadrics[3].powerDensity.set(Vec3(5.0f, 5.0f, 5.0f))
    //area = 2*R*Pi*H (R=1)
    quadrics[3].area.set(Vec1(2.0f*3.14159265358979f*2.0f))
    quadrics[3].clipper.transform(
      Mat4().translate(0f, y0, 0f))    
    quadrics[3].surface.transform(
      Mat4().translate(x0, 0f, 0f))

    quadrics[4].surface.transform(
      Mat4().scale(3f, 3f, 3f)
      .translate(-5.0f, 8.0f)
      )    
    quadrics[4].clipper.transform(
      Mat4().scale(3f, 3f, 3f)
      .translate(-5.0f, 8.0f)
      )
    quadrics[4].ideality.set(Vec3(0.2f, 0.2f, 0.2f))
    quadrics[4].specularCoeff.set(Vec3(0.5f, 0.5f, 0.5f))

    quadrics[5].surface.set(Mat4(
        1.0f, 0.0f, 0.0f, 0.0f,
        0.0f, 2.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 3.0f, 0.0f,
        0.0f, 0.0f, 0.0f, -4.0f
      ))
    quadrics[5].surface.transform(
      Mat4()
      .translate(15.0f, 8.0f)
      )    
    quadrics[5].clipper.transform(
      Mat4().scale(30f, 30f, 30f)
      .translate(-5.0f, 8.0f)
      )
    quadrics[5].ideality.set(Vec3(-1.52f, 0f, 0f))

    quadrics[6].surface.set(Mat4(
      8.0f, 0.0f, 0.0f, 0.0f,
      0.0f, 1.0f, 0.0f, 0.0f,
      0.0f, 0.0f, 1.0f, 0.0f,
      0.0f, 0.0f, 0.0f, -32.0f
    ))
    quadrics[6].surface.transform(
      Mat4()
      .translate(-13.0f, 4.0f, 15.0f)
      )    
    quadrics[6].clipper.transform(
      Mat4().scale(100f, 100f, 100f)
      .translate(-5.0f, 8.0f)
      )
    quadrics[6].absorb.set(Vec3(0.7f, 0.9f, 0.9f))

    lights.add(Light(0))
    lights.add(Light(1))
    lights[0].position.set(5.0f, 4.0f, 5.0f, 1.0f);
    lights[0].powerDensity.set(60.0f, 60.0f, 60.0f);
    lights[1].position.set(1.0f, 1.0f, 0.0f, 0.0f).normalize();
    lights[1].position.xyz.normalize();
    lights[1].powerDensity.set(1.0f, 1.0f, 1.0f);

    envTexture.set(TextureCube(gl, 
      "media/posx512.jpg",
      "media/negx512.jpg",
      "media/posy512.jpg",
      "media/negy512.jpg",
      "media/posz512.jpg",
      "media/negz512.jpg"
    ))
  }

  fun resize(gl : WebGL2RenderingContext, canvas : HTMLCanvasElement) {
    gl.viewport(0, 0, canvas.width, canvas.height)
    camera.setAspectRatio(canvas.width.toFloat() / canvas.height.toFloat())

    defaultFramebuffer = DefaultFramebuffer(canvas.width, canvas.height)
    framebuffers = (
      Framebuffer(gl, 1, canvas.width, canvas.height,
                 GL.RGBA32F, GL.RGBA, GL.FLOAT)
      to
      Framebuffer(gl, 1, canvas.width, canvas.height,
                 GL.RGBA32F, GL.RGBA, GL.FLOAT)
    )

  }

  @Suppress("UNUSED_PARAMETER")
  fun update(gl : WebGL2RenderingContext, keysPressed : Set<String>) {

    val timeAtThisFrame = Date().getTime() 
    val dt = (timeAtThisFrame - timeAtLastFrame).toFloat() / 1000.0f
    val t  = (timeAtThisFrame - timeAtFirstFrame).toFloat() / 1000.0f    
    timeAtLastFrame = timeAtThisFrame
    
    camera.move(dt, keysPressed)

    iFrame.x += 1.0f;

    // clear the screen
    gl.clearColor(0.0f, 0.0f, 0.3f, 1.0f)
    gl.clearDepth(1.0f)
    gl.clear(GL.COLOR_BUFFER_BIT or GL.DEPTH_BUFFER_BIT)
    
    var i = 0
    var j = 0
    val randomInts = Uint32Array(2048)
    crypto.getRandomValues(randomInts)
    while(j < 64 && i < 2048) {
      val x = randomInts[i+0].toFloat() / 4294967295.0f * 2.0f - 1.0f;
      val y = randomInts[i+1].toFloat() / 4294967295.0f * 2.0f - 1.0f;
      val z = randomInts[i+2].toFloat() / 4294967295.0f * 2.0f - 1.0f;
      val w = randomInts[i+3].toFloat() / 4294967295.0f;
      if(x*x+y*y+z*z<1.0f){      
        randoms.set(x, y, z, w);
        j++; // accept
      }
      i+=4;
    }

    i = 0;
    j = 0;
    val randomInts2 = Uint32Array(200)
    crypto.getRandomValues(randomInts2)
    while(j < 100 && i < 200) {
      val phi = 2.0f * 3.1415926535f * randomInts2[i].toFloat() / 4294967295.0f;
      val x = x0 + cos(phi);
      val y = y0-1.0f + randomInts2[i+1].toFloat() / 4294967295.0f * 2.0f;
      val z = sin(phi);

      lightRandoms.set(x, y, z)
      j++
      i+=2
    }

    framebuffers.first.bind(gl)

    previousFrameTexture.set( framebuffers.second.targets[0] )

    traceProgram.draw(this,
      *lights.toTypedArray(),
      *quadrics.toTypedArray(),
      camera)
    quadGeometry.draw()    

    defaultFramebuffer.bind(gl)
    averagedFrameTexture.set( framebuffers.first.targets[0] )    
    showProgram.draw(this, camera)
    quadGeometry.draw()

    framebuffers = framebuffers.second to framebuffers.first    
  }
}
