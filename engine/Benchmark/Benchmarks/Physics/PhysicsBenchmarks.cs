using System;
using BenchmarkDotNet.Attributes;
using Rinten;

namespace Benchmarks.Physics;

//Making bodies and stepping the world. Needs the native core beside the managed build: run with
//RINTEN_ENGINE=<repo>/game `dotnet run -c Release -- physics`.
[MemoryDiagnoser]
public class PhysicsBenchmarks
{
	[Params( 100, 1000, 5000 )]
	public int Bodies { get; set; }

	private Scene scene;
	private PhysicsWorld world;
	private int created;

	[GlobalSetup]
	public void Setup()
	{
		ThreadSafe.MarkMainThread();

		if ( !CoreNative.Available )
			throw new InvalidOperationException( $"The native core did not load ({CoreNative.BuildInfo}) - set RINTEN_ENGINE to the game folder" );

		scene = new Scene();
		world = scene.PhysicsWorld;

		for ( var i = 0; i < Bodies; i++ )
			MakeBody( i );
	}

	[GlobalCleanup]
	public void Cleanup()
	{
		scene.Destroy();
	}

	[Benchmark]
	public void Step() => world.Step( 1.0f / 50.0f );

	[Benchmark]
	public void CreateAndDestroyBody()
	{
		var go = MakeBody( created++ );
		go.Destroy();
		scene.ProcessDeletes();
	}

	private GameObject MakeBody( int index )
	{
		var side = (int)MathF.Ceiling( MathF.Sqrt( Bodies ) );

		var go = new GameObject( scene, true, $"Body {index}" );
		go.WorldPosition = new Vector3( (index % side) * 2.0f, 2.0f + (index / side) * 0.01f, (index / side) * 2.0f );

		go.Components.Create<BoxCollider>();
		go.Components.Create<Rigidbody>();

		return go;
	}
}
