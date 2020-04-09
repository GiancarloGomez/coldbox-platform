/**
 * This is the ColdBox Future object modeled and backed by Java's CompletableFuture but with Dynamic Goodness!
 *
 * @see https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html
 * @see https://docs.oracle.com/en/java/javase/11/docs/api/java.base/java/util/concurrent/CompletableFuture.html
 */
component accessors="true" {

	/**
	 * The native Completable future we model: java.util.concurrent.CompletableFuture
	 */
	property name="native";

	/**
	 * The custom executor to use with the future execution, or it can be null
	 */
	property name="executor";

	/**
	 * Add debugging output to the thread management and operations. Defaults to false
	 */
	property
		name   ="debug"
		type   ="boolean"
		default="false";

	/**
	 * Load the CFML App context and page context's into the spawned threads. Defaults to true
	 */
	property
		name   ="loadAppContext"
		type   ="boolean"
		default="true";

	/**
	 * The timeout you can set on this future via the withTimeout() method
	 * which is used in operations like allOf() and anyOf()
	 */
	property name="futureTimeout" type="struct";

	// Prepare the static time unit class
	this.timeUnit = new util.TimeUnit();

	/**
	 * Construct a new ColdBox Future backed by a Java Completable Future
	 *
	 * @value The actual closure/lambda/udf to run with or a completed value to seed the future with
	 * @executor A custom executor to use with the future, else use the default
	 * @debug Add output debugging
	 * @loadAppContext Load the CFML App contexts or not, disable if not used
	 */
	Future function init(
		value,
		any executor,
		boolean debug          = false,
		boolean loadAppContext = true
	){
		// Preapre the completable future
		variables.native         = createObject( "java", "java.util.concurrent.CompletableFuture" );
		variables.debug          = arguments.debug;
		variables.loadAppContext = arguments.loadAppContext;
		variables.executor 		 = ( isNull( arguments.executor ) ? "" : arguments.executor );
		variables.futureTimeout	 = { "timeout" : 0, "timeUnit" : "milliseconds" };

		// Verify incoming value type
		if ( !isNull( arguments.value ) ) {
			// If the incoming value is a closure/lambda/udf, seed the future with it
			if( isClosure( arguments.value ) || isCustomFunction( arguments.value ) ){
				return run( arguments.value );
			}
			// It is just a value to set as the completion
			variables.native = variables.native.completedFuture( arguments.value );
		}

		return this;
	}

	/**
	 * If not already completed, completes this Future with a CancellationException.
	 * Dependent Futures that have not already completed will also complete exceptionally, with a CompletionException caused by this CancellationException.
	 *
	 * @returns true if this task is now cancelled
	 */
	boolean function cancel( boolean mayInterruptIfRunning = true ){
		return variables.native.cancel( javacast( "boolean", arguments.mayInterruptIfRunning ) );
	}

	/**
	 * If not already completed, sets the value returned by get() and related methods to the given value.
	 *
	 * @value The value to set
	 *
	 * @return true if this invocation caused this CompletableFuture to transition to a completed state, else false
	 */
	boolean function complete( required value ){
		return variables.native.complete( arguments.value );
	}

	/**
	 * Returns a new ColdBox Future that is already completed with the given value.
	 *
	 * @value The value to set
	 *
	 * @return The ColdBox completed future
	 */
	Future function completedFuture( required value ){
		variables.native = variables.native.completedFuture( arguments.value );
		return this;
	}

	/**
	 * If not already completed, causes invocations of get() and related methods to throw the given exception.
	 * The exception type is of `java.lang.RuntimeException` and you can choose the message to throw with it.
	 *
	 * @message An optional message to add to the exception to be thrown.
	 *
	 * @returns The same Future
	 */
	Future function completeExceptionally( message = "Future operation completed with manual exception" ){
		variables.native.completeExceptionally(
			createObject( "java", "java.lang.RuntimeException" ).init( arguments.message )
		);
		return this;
	}

	/**
	 * Waits if necessary for at most the given time for this future to complete, and then returns its result, if available.
	 * If the result is null, then you can pass the defaultValue argument to return it.
	 *
	 * @timeout The timeout value to use, defaults to forever
	 * @timeUnit The time unit to use, available units are: days, hours, microseconds, milliseconds, minutes, nanoseconds, and seconds. The default is milliseconds
	 * @defaultValue If the Future did not produce a value, then it will return this default value.
	 *
	 * @returns The result value
	 * @throws CancellationException, ExecutionException, InterruptedException, TimeoutException
	 */
	any function get(
		numeric timeout = 0,
		string timeUnit = "milliseconds",
		defaultValue
	){
		// Do we have a timeout?
		if ( arguments.timeout != 0 ) {
			var results = variables.native.get(
				javacast( "long", arguments.timeout ),
				this.timeUnit.get( arguments.timeUnit )
			);
		} else {
			var results = variables.native.get();
		}

		// If we have results, return them
		if ( !isNull( results ) ) {
			return results;
		}

		// If we didn't, do we have a default value
		if ( !isNull( arguments.defaultValue ) ) {
			return arguments.defaultValue;
		}
		// Else return null
	}

	/**
	 * Returns the result value (or throws any encountered exception) if completed, else returns the given defaultValue.
	 *
	 * @defaultValue The value to return if not completed
	 *
	 * @returns The result value, if completed, else the given defaultValue
	 *
	 * @throws CancellationException, CompletionException
	 */
	function getNow( required defaultValue ){
		return variables.native.getNow( arguments.defaultValue );
	}

	/**
	 * Returns true if this Future was cancelled before it completed normally.
	 */
	boolean function isCancelled(){
		return variables.native.isCancelled();
	}

	/**
	 * Returns true if this Future completed exceptionally, in any way. Possible causes include cancellation, explicit invocation of completeWithException, and abrupt termination of a CompletionStage action.
	 */
	boolean function isCompletedExceptionally(){
		return variables.native.isCompletedExceptionally();
	}

	/**
	 * Returns true if completed in any fashion: normally, exceptionally, or via cancellation.
	 */
	boolean function isDone(){
		return variables.native.isDone();
	}

	/**
	 * Register an event handler for any exceptions that happen before it is registered
	 * in the future pipeline.  Whatever this function returns, will be used for the next
	 * registered functions in the pipeline.
	 *
	 * The function takes in the exception that ocurred and can return a new value as well:
	 *
	 * <pre>
	 * ( exception ) => newValue;
	 * function( exception ) => {
	 * 	  return newValue;
	 * }
	 * </pre>
	 *
	 * Note that, the error will not be propagated further in the callback chain if you handle it once.
	 *
	 * @target The function that will be called when the exception is triggered
	 *
	 * @return The future with the exception handler registered
	 */
	Future function exceptionally( required target ){
		variables.native = variables.native.exceptionally(
			createDynamicProxy(
				new proxies.Function(
					arguments.target,
					variables.debug,
					variables.loadAppContext
				),
				[ "java.util.function.Function" ]
			)
		);
		return this;
	}

	/**
	 * Alias to exceptionally()
	 */
	function onException( required target ){
		return exceptionally( argumentCollection=arguments );
	}

	/**
	 * Executes a runnable closure or component method via Java's CompletableFuture and gives you back a ColdBox Future:
	 *
	 * - This method calls `supplyAsync()` in the Java API
	 * - This future is asynchronously completed by a task running in the ForkJoinPool.commonPool() with the value obtained by calling the given Supplier.
	 *
	 * @supplier A CFC instance or closure or lambda or udf to execute and return the value to be used in the future
	 * @method If the supplier is a CFC, then it executes a method on the CFC for you. Defaults to the `run()` method
	 * @executor An optional executor to use for asynchronous execution of the task
	 *
	 * @return The new completion stage (Future)
	 */
	Future function run(
		required supplier,
		method = "run",
		any executor=variables.executor
	){
		var jSupplier = createDynamicProxy(
			new proxies.Supplier(
				arguments.supplier,
				arguments.method,
				variables.debug,
				variables.loadAppContext
			),
			[ "java.util.function.Supplier" ]
		);

		// Supply the future and start the task
		if( isObject( variables.executor ) ){
			variables.native = variables.native.supplyAsync( jSupplier, variables.executor );
		} else {
			variables.native = variables.native.supplyAsync( jSupplier );
		}

		return this;
	}

	/**
	 * Alias to the `run()` method but left here to help Java developers
	 * feel at home. Since in our futures, everything becomes a supplier
	 * of some sort.
	 *
	 * @supplier A CFC instance or closure or lambda or udf to execute and return the value to be used in the future
	 * @executor An optional executor to use for asynchronous execution of the task
	 *
	 * @return The new completion stage (Future)
	 */
	Future function supplyAsync( required supplier, any executor ){
		return run( argumentCollection=arguments );
	}

	/**
	 * Alias to the `run()` method but left here to help Java developers
	 * feel at home. Since in our futures, everything becomes a supplier
	 * of some sort.
	 *
	 * @runnable A CFC instance or closure or lambda or udf to execute and return the value to be used in the future
	 * @executor An optional executor to use for asynchronous execution of the task
	 *
	 * @return The new completion stage (Future)
	 */
	Future function runAsync( required runnable, any executor ){
		arguments.supplier = arguments.runnable;
		return run( argumentCollection=arguments );
	}

	/**
	 * Executed once the computation has finalized and a result is passed in to the target:
	 *
	 * - The target can use the result, manipulate it and return a new result from the this completion stage
	 * - The target can use the result and return void
	 * - This stage executes in the calling thread
	 *
	 * <pre>
	 * // Just use the result and not return anything
	 * then( (result) => systemOutput( result ) )
	 * // Get the result and manipulate it, much like a map() function
	 * then( (result) => ucase( result ) );
	 * </pre>
	 *
	 * @target The closure/lambda or udf that will receive the result
	 *
	 * @return The new completion stage (Future)
	 */
	Future function then( required target ){
		var apply = createDynamicProxy(
			new proxies.Function(
				arguments.target,
				variables.debug,
				variables.loadAppContext
			),
			[ "java.util.function.Function" ]
		);

		variables.native = variables.native.thenApply( apply );

		return this;
	}

	/**
	 * Alias to `then()` left to help Java devs feel at Home
	 */
	Future function thenApply(){
		return then( argumentCollection=arguments );
	}

	/**
	 * Executed once the computation has finalized and a result is passed in to the target but
	 * this will execute in a separate thread. By default it uses the ForkJoin.commonPool() but you can
	 * pass your own executor service.
	 *
	 * - The target can use the result, manipulate it and return a new result from the this completion stage
	 * - The target can use the result and return void
	 *
	 * <pre>
	 * // Just use the result and not return anything
	 * then( (result) => systemOutput( result ) )
	 * // Get the result and manipulate it, much like a map() function
	 * then( (result) => ucase( result ) );
	 * </pre>
	 *
	 * @target The closure/lambda or udf that will receive the result
	 *
	 * @return The new completion stage (Future)
	 */
	Future function thenAsync( required target, executor ){
		var apply = createDynamicProxy(
			new proxies.Function(
				arguments.target,
				variables.debug,
				variables.loadAppContext
			),
			[ "java.util.function.Function" ]
		);

		if( isNull( arguments.executor ) ){
			variables.native = variables.native.thenApplyAsync( apply );
		} else {
			variables.native = variables.native.thenApplyAsync( apply, arguments.executor );
		}

		return this;
	}

	/**
	 * Alias to `thenAsync()` left to help Java devs feel at Home
	 */
	Future function thenApplyAsync(){
		return thenAsync( argumentCollection=arguments );
	}

	/**
	 * Returns a new CompletionStage that, when this stage completes normally,
	 * is executed with this stage as the argument to the supplied function.
	 *
	 * Basically, this used to combine two Futures where one future is dependent on the other
	 * If not, you return a future of a future
	 *
	 * @fn the function returning a new CompletionStage
	 *
	 * @return the CompletionStage
	 */
	Future function thenCompose( required fn ){
		variables.native = variables.native.thenCompose(
			createDynamicProxy(
				new proxies.FutureFunction(
					arguments.fn,
					variables.debug,
					variables.loadAppContext
				),
				[ "java.util.function.Function" ]
			)
		);
		return this;
	}

	/**
	 * This used when you want two Futures to run independently and do something after
	 * both are complete.
	 *
	 * @future The ColdBox Future to combine
	 * @fn The closure that will combine them: ( r1, r2 ) =>
	 */
	Future function thenCombine( required future, fn ){
		variables.native = variables.native.thenCombine(
			arguments.future.getNative(),
			createDynamicProxy(
				new proxies.BiFunction(
					arguments.fn,
					variables.debug,
					variables.loadAppContext
				),
				[ "java.util.function.BiFunction" ]
			)
		);
		return this;
	}

	/**
	 * This method accepts an infinite amount of future objects or closures in order to execute them in parallel,
	 * waits for them and then processes their combined results into an array of results.
	 *
	 * <pre>
	 * results = allOf( f1, f2, f3 )
	 * </pre>
	 *
	 * @result An array containing all of the collected results
	 */
	array function allOf(){
		// Collect the java futures to send back into this one for parallel exec
		var jFutures = futuresWrap( argumentCollection=arguments );

		// Run them and wait for them!
		variables.native.allOf( jFutures ).get(
			javaCast( "long", variables.futureTimeout.timeout ),
			this.timeUnit.get( variables.futureTimeout.timeUnit )
		);

		// return back the completed array results in the order they came in
		return jFutures.map( function( jFuture ){
			return jFuture.get();
		} );
	}

	/**
	 * This function can accept an array of items and apply a function
	 * to each of the item's in parallel.  The `fn` argument receives the appropriate item
	 * and must return a result.  Consider this a parallel map() operation
	 *
	 * <pre>
	 * allApply( items, ( item ) => item.getMemento() )
	 * </pre>
	 *
	 * @items An array to process
	 * @fn The function that will be applied to each of the array's items
	 * @executor The custom executor to use if passed, else the forkJoin Pool
	 *
	 * @return An array with the items processed
	 */
	array function allApply( array items, required fn, executor ){
		return arguments.items
			.map( function( thisItem ){
				if( isObject( executor ) ){
					return new Future( thisItem ).thenAsync( fn, executor );
				}
				return new Future( thisItem ).thenAsync( fn );
			} )
			.map( function( thisFuture ) {
				return thisFuture.get(
					javaCast( "long", variables.futureTimeout.timeout ),
					this.timeUnit.get( variables.futureTimeout.timeUnit )
				);
			} );
	}

	/**
	 * This method accepts an infinite amount of future objects or closures and will execute them in parallel.
	 * However, instead of returning all of the results in an array like allOf(), this method will return
	 * the future that executes the fastest!
	 *
	 * <pre>
	 * // Let's say f2 executes the fastest!
	 * f2 = anyOf( f1, f2, f3 )
	 * </pre>
	 *
	 * @return The fastest executed future
	 */
	Future function anyOf(){
		// Run the fastest future in the world!
		variables.native = variables.native.anyOf(
			futuresWrap( argumentCollection=arguments )
		);

		return this;
	}

	/**
	 * This method seeds a timeout into this future that can be used by the following operations:
	 *
	 * - allOf()
	 * - allApply()
	 *
	 * @timeout The timeout value to use, defaults to forever
	 * @timeUnit The time unit to use, available units are: days, hours, microseconds, milliseconds, minutes, nanoseconds, and seconds. The default is milliseconds
	 *
	 * @returns This future
	 */
	Future function withTimeout(
		numeric timeout = 0,
		string timeUnit = "milliseconds"
	){
		variables.futureTimeout = arguments;
		return this;
	}

	/****************************************************************
	 * Private Functions *
	 ****************************************************************/

	/**
	 * This utility wraps in the coming futures or closures and makes sure the return
	 * is an array of futures.
	 */
	private function futuresWrap(){
		return arguments
			// If the passed in argument is a closure/udf, convert to a future
			.map( function( key, future ){
				if( isClosure( arguments.future ) || isCustomFunction( arguments.future ) ){
					return new Future().run( arguments.future );
				}
				return arguments.future;
			} )
			.reduce( function( results, key, future ){
				// Now process it
				results.append( arguments.future.getNative() );
				return results;
			}, [] );
	}

}
