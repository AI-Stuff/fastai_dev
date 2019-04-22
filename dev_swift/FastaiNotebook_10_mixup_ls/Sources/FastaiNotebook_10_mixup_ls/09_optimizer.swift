/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: /home/ubuntu/fastai_docs/dev_swift/09_optimizer.ipynb/lastPathComponent

*/
        
import Path
import TensorFlow

//Expandable enum to have easier names than LearningRate.self.
public struct HyperParams {
    public static let lr = LearningRate.self
}

open class StatDelegate {
    open var name: String { return "" }
    var defaultConfig: HeterogeneousDictionary { return HeterogeneousDictionary() }
    public init() {}
    public func update(
        state: inout [String: Tensor<Float>],
        for param: Tensor<Float>,
        along direction: Tensor<Float>,
        config: inout HeterogeneousDictionary
    ) { }
}

//export
open class StepDelegate {
    var defaultConfig: HeterogeneousDictionary { return HeterogeneousDictionary() }
    public init() {}
    public func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) { }
}

public extension Tensor where Scalar: Numeric {
    mutating func reset0() {
        self = Tensor(0)
    }
}

public class StatefulOptimizer<Model: Layer>
    where Model.AllDifferentiableVariables == Model.CotangentVector{
    public var configs: [HeterogeneousDictionary]
    public var splitFunc: (Int) -> Int
    public var states: [String: Model.AllDifferentiableVariables]
    public var statDelegates: [StatDelegate]
    public var stepDelegates: [StepDelegate]
    public init(
        for model: __shared Model,
        stepDelegates: [StepDelegate],
        statDelegates: [StatDelegate],
        configs: [HeterogeneousDictionary],
        splitFunc: @escaping (Int) -> Int
    ) {
        self.configs = Array(repeating: HeterogeneousDictionary(), count: configs.count)
        states = [:]
        for stepDelegate in stepDelegates {
            for i in self.configs.indices { self.configs[i].merge(stepDelegate.defaultConfig) { (_, new) in new } }
        }
        for statDelegate in statDelegates {
            for i in self.configs.indices { self.configs[i].merge(statDelegate.defaultConfig) { (_, new) in new } }
            states[statDelegate.name] = model.allDifferentiableVariables
            for kp in states[statDelegate.name]!.keyPaths { 
                states[statDelegate.name]![keyPath: kp].reset0()
            }
        }
        for i in 0..<configs.count {
            self.configs[i].merge(configs[i]) { (_, new) in new }
        }
        self.stepDelegates = stepDelegates
        self.statDelegates = statDelegates
        self.splitFunc = splitFunc
    }
        
    public func update(
        _ model: inout Model.AllDifferentiableVariables,
        along direction: Model.CotangentVector
    ) {
        for (i,kp) in model.keyPaths.enumerated() {
            var grad = direction[keyPath: kp]
            var state = states.mapValues(){$0[keyPath: kp]}
            var config = configs[splitFunc(i)]
            for statDelegate in statDelegates {
                statDelegate.update(
                    state: &state,
                    for: model[keyPath: kp],
                    along: grad,
                    config: &config
                )
            }
            for n in states.keys { states[n]![keyPath: kp] = state[n]! }
            for stepDelegate in stepDelegates {
                stepDelegate.update(
                    param: &model[keyPath: kp],
                    along: &grad,
                    state: state,
                    config: &config
                )
            }
            configs[splitFunc(i)] = config
        }
    }
}

extension StatefulOptimizer: Optimizer{
    public var learningRate: Float {
        get { return configs.last![HyperParams.lr] } 
        set { 
            for i in configs.indices {self.configs[i][HyperParams.lr] = newValue }
        }
    }
    public var learningRates: [Float] {
        get {
            var res: [Float] = []
            for config in configs {res.append(config[HyperParams.lr])}
            return res
        }
        set { 
            for i in configs.indices {self.configs[i][HyperParams.lr] = newValue[i] } 
        }
    }
}

extension StatefulOptimizer{
    public convenience init (for model: __shared Model,
                             stepDelegates: [StepDelegate],
                             statDelegates: [StatDelegate],
                             config: HeterogeneousDictionary) {
        self.init(for: model,
                  stepDelegates: stepDelegates,
                  statDelegates: statDelegates,
                  configs: [config],
                  splitFunc: { _ in return 0 })
    }
}

public class SGDStep: StepDelegate {
    override public func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        param -= direction * config[HyperParams.lr]
    }
}

public struct WeightDecayKey: HetDictKey { public static var defaultValue: Float = 0 }

public extension HyperParams {
    static let wd = WeightDecayKey.self
}

public class WeightDecay: StepDelegate {
    override public func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        param *= 1 - config[HyperParams.lr] * config[HyperParams.wd]
    }
}

public class L2Regularization: StepDelegate {
    override public func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        direction += config[HyperParams.wd] * param
    }
}

//Expandable enum to have tab completes/typo-proof for state variable names.
public struct StateKeys {
    public static let avgGrad = "averageGrad"
}


public struct Momentum: HetDictKey { public static var defaultValue: Float = 0.9 }
public struct MomentumDampening: HetDictKey, Equatable { public static var defaultValue: Float = 0.1 }
public extension HyperParams {
    static let mom = Momentum.self
    static let momDamp = MomentumDampening.self
}

public class AverageGrad: StatDelegate {
    public let dampened: Bool
    public init(dampened: Bool = false) { self.dampened = dampened }
    override public var name: String { return StateKeys.avgGrad }
    override public func update(
        state: inout [String: Tensor<Float>],
        for param: Tensor<Float>,
        along direction: Tensor<Float>,
        config: inout HeterogeneousDictionary
    ) {
        state[StateKeys.avgGrad]! *= config[HyperParams.mom]
        config[HyperParams.momDamp] = 1.0 - (dampened ? config[HyperParams.mom] : 0.0)
        state[StateKeys.avgGrad]! += config[HyperParams.momDamp] * direction
    }
}

public class MomentumStep: StepDelegate {
    override public func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        param -= state[StateKeys.avgGrad]! * config[HyperParams.lr]
    }
}

public struct SquareMomentum: HetDictKey { public static var defaultValue: Float = 0.99 }
public struct SquareMomentumDampening: HetDictKey { public static var defaultValue: Float = 0.99 }

public extension HyperParams {
    static let ²mom = Momentum.self
    static let ²momDamp = MomentumDampening.self
}

public extension StateKeys {
    static let avgSqr = "averageSquaredGrad"
}

public class AverageSquaredGrad: StatDelegate {
    let dampened: Bool
    public init(dampened: Bool = true) { self.dampened = dampened }
    override public var name: String { return StateKeys.avgSqr }
    override public func update(
        state: inout [String: Tensor<Float>],
        for param: Tensor<Float>,
        along direction: Tensor<Float>,
        config: inout HeterogeneousDictionary
    ) {
        state[StateKeys.avgSqr]! *= config[HyperParams.²mom]
        config[HyperParams.²momDamp] = 1.0 - (dampened ? config[HyperParams.²mom] : 0.0)
        state[StateKeys.avgSqr]! += config[HyperParams.²momDamp] * direction.squared()
    }
}

public extension StateKeys {
    static let step = "stepCount"
}

public class StepCount: StatDelegate {
    override public var name: String { return StateKeys.step }
    override public func update(
        state: inout [String: Tensor<Float>],
        for param: Tensor<Float>,
        along direction: Tensor<Float>,
        config: inout HeterogeneousDictionary
    ) {
        state[StateKeys.step]! += 1.0
    }
}

public struct Epsilon: HetDictKey { public static var defaultValue: Float = 1e-5 }
public extension HyperParams {
    static let eps = Epsilon.self
}

public class AdamStep: StepDelegate {
    override public func update(
        param: inout Tensor<Float>,
        along direction: inout Tensor<Float>,
        state: [String: Tensor<Float>],
        config: inout HeterogeneousDictionary
    ) {
        let step = state[StateKeys.step]!
        let (mom,damp) = (config[HyperParams.mom],config[HyperParams.momDamp])
        let debias1 = damp * (1 - pow(mom, step)) / (1 - mom)
        let num = debias1 * state[StateKeys.avgGrad]!
        
        let (²mom,²damp) = (config[HyperParams.²mom],config[HyperParams.²momDamp])
        let debias2 = ²damp * (1 - pow(²mom, step)) / (1 - ²mom)
        let denom = sqrt(state[StateKeys.avgSqr]!/debias2) + config[HyperParams.eps]
        
        param -= config[HyperParams.lr] * num / denom
    }
}

public func SGDOpt<Model>(lr: Float, mom: Float = 0.9, wd: Float = 0.0, dampening: Bool = false
                         ) -> ((Model) -> StatefulOptimizer<Model>) {
    var steppers = (mom != 0) ? [MomentumStep()] : [SGDStep()]
    if wd != 0 { steppers.append(WeightDecay()) }
    let stats = (mom != 0) ? [AverageGrad(dampened: dampening)] : []
    var config = HeterogeneousDictionary(HyperParams.lr, lr)
    if mom != 0 { config[HyperParams.mom] = mom }
    if wd != 0  { config[HyperParams.wd ] = wd  }
    return {model in 
        return StatefulOptimizer(for: model, stepDelegates: steppers, statDelegates: stats, config: config)}
}

public func AdamOpt<Model>(lr: Float, mom: Float = 0.9, beta: Float=0.99, wd: Float = 0.0, eps: Float = 1e-5
                         ) -> ((Model) -> StatefulOptimizer<Model>) {
    var steppers: [StepDelegate] = [AdamStep()]
    if wd != 0 { steppers.append(WeightDecay()) }
    let stats = [AverageGrad(dampened: true), AverageSquaredGrad(), StepCount()]
    var config = HeterogeneousDictionary(HyperParams.lr, lr)
    config[HyperParams.mom] = mom
    config[HyperParams.²mom] = beta
    config[HyperParams.eps] = eps
    if wd != 0  { config[HyperParams.wd ] = wd  }
    return {model in 
        return StatefulOptimizer(for: model, stepDelegates: steppers, statDelegates: stats, config: config)}
}
