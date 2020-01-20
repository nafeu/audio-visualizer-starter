import arg from 'arg';
import inquirer from 'inquirer';
import execa from 'execa';
import _ from 'lodash';
import { handleCreateCommand } from './components/create';

function parseArgumentsIntoOptions(rawArgs) {
    const args = arg(
        {
            // '--yes': Boolean,
            // '-y': '--yes',
        },
        {
            argv: rawArgs.slice(2),
        }
    )
    return {
        // skipPrompts: args['--yes'] || false,
        // execution: args['--yes'] || false,
        command: args._[0],
    }
}

const VALID_COMMANDS = ['create', 'build'];
const DEFAULT_COMMAND = 'create';

async function promptForMissingCommand(options) {
    const questions = [];

    const isInvalidCommand = options.command && _.includes(VALID_COMMANDS, _.toLower(options.command));

    if (isInvalidCommand) {
      console.log(`[ oavp ] Command '${options.command}' not recognized.`)
    }

    if (!options.command) {
        questions.push({
            type: 'list',
            name: 'command',
            message: 'Please select a command:',
            choices: VALID_COMMANDS,
            default: DEFAULT_COMMAND
        });
    }

    const answers = await inquirer.prompt(questions);

    return {
        ...options,
        command: options.command || answers.command,
    }
}

async function handleOptions({ command }) {
  switch (command) {
    case 'create':
      await handleCreateCommand();
      break;
    default:
      await handleCreateCommand();
  }
}

export async function cli(args) {
    let options = parseArgumentsIntoOptions(args);
    options = await promptForMissingCommand(options);
    try {
        await handleOptions(options);
    } catch(err) {
        console.log(err.message);
    }
}
