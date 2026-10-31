param(
    [Parameter(Position = 0)]
    [string]$ProjectPath
)

$ErrorActionPreference = "Stop"


if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    Write-Host "Error: No project path defined." -ForegroundColor Red
    Write-Host "Usage: .\create-tsoa-project.ps1 <project-path>"
    exit 1
}


if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {

    Write-Host "pnpm not found. Checking npm..."

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Installing pnpm..."

        npm install -g pnpm@latest-11

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install pnpm."
        }
    }
    else {
        throw "Neither pnpm nor npm was found. Install Node.js first."
    }
}


$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)

New-Item -ItemType Directory -Force -Path $ProjectPath | Out-Null

Set-Location $ProjectPath

Write-Host "Creating tsoa project in $ProjectPath" -ForegroundColor Green


pnpm init

if ($LASTEXITCODE -ne 0) {
    throw "Failed to initialize project."
}

pnpm add --allow-build=@scarf/scarf --allow-build=esbuild tsoa express @tsoa/runtime swagger-ui-express cors multer

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install dependencies."
}

pnpm add -D ts-node-dev typescript @types/node @types/express @types/cors @types/multer tsx @types/swagger-ui-express

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install development dependencies."
}


pnpm approve-builds --all


pnpm tsc --init

if ($LASTEXITCODE -ne 0) {
    throw "Failed to initialize TypeScript."
}


$Directories = @(
    "src",
    "src/controllers",
    "src/services"
)

foreach ($Directory in $Directories) {
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
}

New-Item -ItemType File -Force -Path "src/main.ts" | Out-Null


@"
node_modules/
.env
"@ | Set-Content -Path ".gitignore"


@"
{
    "entryFile": "src/main.ts",
    "noImplicitAdditionalProperties": "throw-on-extras",
    "controllerPathGlobs": ["src/**/*Controller.ts"],
    "spec": {
        "outputDirectory": ".",
        "specVersion": 3.1
    },
    "routes": {
        "basePath": "/",
        "routesDir": "src",
        "middleware": "express"
    }
}
"@ | Set-Content -Path "tsoa.json"


@"
{
    "compilerOptions": {
        "rootDir": "./src",
        "module": "nodenext",
        "target": "esnext",
        "lib": ["esnext"],
        "types": ["node"],
        "noUncheckedIndexedAccess": true,
        "exactOptionalPropertyTypes": false,
        "strict": true,
        "jsx": "react-jsx",
        "verbatimModuleSyntax": false,
        "isolatedModules": true,
        "noUncheckedSideEffectImports": true,
        "moduleDetection": "force",
        "skipLibCheck": true,
        "noEmit": true,
        "emitDecoratorMetadata": true,
        "experimentalDecorators": true
    }
}
"@ | Set-Content -Path "tsconfig.json"


$PackageJson = Get-Content "package.json" -Raw | ConvertFrom-Json

$PackageJson.type = "commonjs"

$PackageJson.scripts | Add-Member `
    -MemberType NoteProperty `
    -Name "start" `
    -Value "pnpm tsoa spec-and-routes && pnpm tsx watch src/main.ts" `
    -Force

$PackageJson | ConvertTo-Json -Depth 100 | Set-Content "package.json"


@'
import express, { NextFunction, Request, Response } from "express";
import { RegisterRoutes } from "./routes";
import multer, { memoryStorage } from "multer";
import swaggerUi from "swagger-ui-express";
import swaggerDocument from "../swagger.json";
import cors from "cors";

const app = express();

app.use(cors({ origin: "http://localhost", credentials: true }));
app.use(express.urlencoded());
app.use(express.json());

app.use((req, res, next) => {
    console.log(`Request ${req.method} on endpoint ${req.url} received.`);
    next();
});

const storage = multer({ storage: memoryStorage() });
RegisterRoutes(app, { multer: storage });

app.use("/docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));

app.get("/", (req: Request, res: Response) => {
    return res.status(200).send("Success");
});

app.use((err: unknown, req: Request, res: Response, next: NextFunction) => {
    if (err instanceof Error) {
        return res.status(500).send({
            message: err.message,
            stack: err.stack,
            cause: err.cause
        });
    }

    next();
});

app.listen(3000, "0.0.0.0", async () => {
    console.log("Server listening on port 3000");
});
'@ | Set-Content -Path "src/main.ts" -Encoding UTF8


@'
import { Controller, Route, Get, SuccessResponse } from "tsoa";

@Route("/test")
export class TestController extends Controller {
    @Get("")
    @SuccessResponse(200, "success")
    public getTest() {
        return "Hello world";
    }
}
'@ | Set-Content -Path "src/controllers/testController.ts" -Encoding UTF8


Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host " TSOA project created successfully!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Project path: $ProjectPath"
Write-Host "Run the project using:"
Write-Host "pnpm start"
