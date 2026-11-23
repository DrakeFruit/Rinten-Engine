using System.Linq;
using BenchmarkDotNet.Attributes;
using Rinten;

namespace Benchmarks.Scenes;

//What components cost: adding one, finding one, destroying one, and the tag and connection lookups built on the same
//lists. Run with `dotnet run -c Release -- components`.
[MemoryDiagnoser]
public class ComponentBenchmarks
{
	private Scene scene;
	private GameObject owner;
	private BenchComponent existing;

	[GlobalSetup]
	public void Setup()
	{
		ThreadSafe.MarkMainThread();

		scene = new Scene();
		owner = new GameObject( scene, true, "Owner" );

		existing = owner.Components.Create<BenchComponent>();
		owner.Tags.Add( "player" );
		owner.Tags.Add( "bench" );
	}

	[GlobalCleanup]
	public void Cleanup()
	{
		scene.Destroy();
	}

	[Benchmark]
	public BenchComponent Add()
	{
		var component = owner.Components.Create<BenchComponent>();
		component.Destroy();
		return component;
	}

	[Benchmark]
	public BenchComponent Get() => owner.Components.Get<BenchComponent>();

	[Benchmark]
	public bool TagsContains() => owner.Tags.Has( "player" );

	[Benchmark]
	public int FindByTag() => scene.FindAllWithTag( "player" ).Count();

	//Reading the connection list is what every broadcast walks; empty here, but the list and its lock are real.
	[Benchmark]
	public int Connections() => Connection.All.Count;

	public sealed class BenchComponent : Component { }
}
