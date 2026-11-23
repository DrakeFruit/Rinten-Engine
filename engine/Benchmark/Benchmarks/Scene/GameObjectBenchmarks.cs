using System.Linq;
using BenchmarkDotNet.Attributes;
using Rinten;

namespace Benchmarks.Scenes;

//The object model a scene is made of: making objects, throwing them away, cloning a subtree, walking it, and moving
//something. Run with `dotnet run -c Release -- scene`.
[MemoryDiagnoser]
public class GameObjectBenchmarks
{
	private Scene scene;
	private GameObject moving;
	private GameObject subtree;

	[GlobalSetup]
	public void Setup()
	{
		ThreadSafe.MarkMainThread();

		//A scene of its own, so nothing depends on an active scene being set by the engine loop.
		scene = new Scene();

		for ( var i = 0; i < 1000; i++ )
			new GameObject( scene, true, $"Cached {i}" );

		moving = new GameObject( scene, true, "Moving" );

		//A small subtree to clone: a root with children and a component on each.
		subtree = new GameObject( scene, true, "Subtree" );
		for ( var i = 0; i < 10; i++ )
		{
			var child = new GameObject( subtree, true, $"Child {i}" );
			child.Components.Create<BenchComponent>();
		}
	}

	[GlobalCleanup]
	public void Cleanup()
	{
		scene.Destroy();
	}

	[Benchmark]
	public GameObject Create() => new GameObject( scene, true, "Created" );

	[Benchmark]
	public int CreateAndDestroy()
	{
		var go = new GameObject( scene, true, "Temporary" );
		go.Destroy();
		scene.ProcessDeletes();
		return scene.Children.Count;
	}

	[Benchmark]
	public GameObject CloneSubtree() => subtree.Clone();

	[Benchmark]
	public int Walk()
	{
		var count = 0;
		foreach ( var _ in scene.GetAllObjects( true ) ) count++;
		return count;
	}

	[Benchmark]
	public Vector3 SetWorldPosition()
	{
		moving.WorldPosition = new Vector3( 1.0f, 2.0f, 3.0f );
		return moving.WorldPosition;
	}

	//A component with nothing in it, so adding one measures the list rather than the component.
	public sealed class BenchComponent : Component { }
}
