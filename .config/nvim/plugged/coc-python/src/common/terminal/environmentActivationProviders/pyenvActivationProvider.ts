// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

'use strict'

import { inject, injectable } from 'inversify'
import { Uri } from 'coc.nvim'
import { IInterpreterService, InterpreterType } from '../../../interpreter/contracts'
import { IServiceContainer } from '../../../ioc/types'
import { ITerminalActivationCommandProvider, TerminalShellType } from '../types'
import { toCommandArgument } from '../../string'

@injectable()
export class PyEnvActivationCommandProvider implements ITerminalActivationCommandProvider {
  constructor(@inject(IServiceContainer) private readonly serviceContainer: IServiceContainer) { }

  public isShellSupported(_targetShell: TerminalShellType): boolean {
    return true
  }

  public async getActivationCommands(resource: Uri | undefined, _: TerminalShellType): Promise<string[] | undefined> {
    const interpreter = await this.serviceContainer.get<IInterpreterService>(IInterpreterService).getActiveInterpreter(resource)
    if (!interpreter || interpreter.type !== InterpreterType.Pyenv || !interpreter.envName) {
      return
    }

    return [`pyenv shell ${toCommandArgument(interpreter.envName)}`]
  }

  public async getActivationCommandsForInterpreter(pythonPath: string, _targetShell: TerminalShellType): Promise<string[] | undefined> {
    const interpreter = await this.serviceContainer.get<IInterpreterService>(IInterpreterService).getInterpreterDetails(pythonPath)
    if (!interpreter || interpreter.type !== InterpreterType.Pyenv || !interpreter.envName) {
      return
    }

    return [`pyenv shell ${toCommandArgument(interpreter.envName)}`]
  }

}
