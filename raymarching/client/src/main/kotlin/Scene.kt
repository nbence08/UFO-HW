import org.w3c.dom.HTMLCanvasElement
import org.khronos.webgl.WebGLRenderingContext as GL
import org.khronos.webgl.Float32Array
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
  val traceProgram = Program(gl, vsQuad, fsTrace, Program.PNT)
  val quadGeometry = TexturedQuadGeometry(gl)  

  val timeAtFirstFrame = Date().getTime()
  var timeAtLastFrame =  timeAtFirstFrame

  val camera = PerspectiveCamera(*Program.all)
/*
  val quadrics = ArrayList<Quadric>()
  val lights = ArrayList<Light>()
*/
  
  /*for sake of convenience the float represents how to make tha volume appear
    M-MATCAP
    B-BASIC
    G-GAS LIKE CLOUD
  */
  var mode by Vec1()
  var threshold by Vec1()

  val matcapTexture by Sampler2D()
  val volumeTexture by Sampler3D()

  lateinit var defaultFramebuffer : DefaultFramebuffer  
  lateinit var framebuffers : Pair<Framebuffer, Framebuffer>

  val x0 = -18.0f
  val y0 = 8.0f

  init {
    addComponentsAndGatherUniforms(*Program.all)

    volumeTexture.set(Texture3D(gl, "media/brain-at_4096.jpg"))
    matcapTexture.set(Texture2D(gl, "media/matcap.jpg"))
    mode.set(0.5f)
    threshold.set(0.25f)
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

    if("M" in keysPressed) { 
      mode.set(-0.5f)
    }
    if("B" in keysPressed) { 
      mode.set(0.5f)
    }
    if("G" in keysPressed){
      mode.set(1.5f)
    }
    if("N" in keysPressed){
      mode.set(1000.0f)
    }
    if("L" in keysPressed){
      mode.set(2.5f)
    }
    if("P" in keysPressed){
      threshold.plusAssign(Vec1(0.01f))
    }
    if("O" in keysPressed){
      threshold.minusAssign(Vec1(0.01f))
    }

    // clear the screen
    gl.clearColor(0.0f, 0.0f, 0.3f, 1.0f)
    gl.clearDepth(1.0f)
    gl.clear(GL.COLOR_BUFFER_BIT or GL.DEPTH_BUFFER_BIT)

    traceProgram.draw(this,
      /**lights.toTypedArray(),
      *quadrics.toTypedArray(),*/
      camera)
    quadGeometry.draw()

    defaultFramebuffer.bind(gl)
  }
}
