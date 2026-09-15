#include <arpa/inet.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define PUERTO 8080
#define TAMANO_COLA 128
#define TAMANO_PETICION 4096

//Envía el buffer completo, reintentando tras interrupciones o envíos parciales
static int enviar_todo(int descriptor, const char *datos, size_t longitud)
{
    size_t enviados = 0;
    
    while (enviados < longitud) {

        //El puntero se desplaza hasta el primer byte que aún no se ha enviado
        ssize_t resultado = send(descriptor, datos + enviados,
                                 longitud - enviados, 0);  

        if (resultado < 0) {
            if (errno == EINTR) { 
                continue;   //send() interrumpido, se reintenta
            }
            return -1;      
        }

        //Evita un bucle infinito si send() no avanza
        if (resultado == 0) {
            return -1;      
	}

        enviados += (size_t)resultado;
    }
    return 0;
}

//Construye y envía una respuesta HTTP/1.1
static int enviar_respuesta(int cliente, int codigo, const char *motivo,
                            const char *cabeceras_adicionales,
                            const char *cuerpo)
{
    char cabeceras[1024];
    size_t longitud_cuerpo = strlen(cuerpo);
    //snprintf() limita la escritura al tamaño del buffer
    int longitud_cabeceras = snprintf(  
        cabeceras, sizeof(cabeceras),
        "HTTP/1.1 %d %s\r\n"
        "Server: tfg-http/1.0\r\n"
        "Content-Type: text/plain; charset=utf-8\r\n"
        "Content-Length: %zu\r\n"
        "%s"
        "Connection: close\r\n"
        "\r\n",                         //línea vacía para separar cabeceras del cuerpo
        codigo, motivo, longitud_cuerpo, cabeceras_adicionales);

    //Comprueba errores o truncamiento de las cabeceras
    if (longitud_cabeceras < 0 ||       
        (size_t)longitud_cabeceras >= sizeof(cabeceras)) {
        return -1;
    }

    if (enviar_todo(cliente, cabeceras, (size_t)longitud_cabeceras) < 0) {
        return -1;
    }
    return enviar_todo(cliente, cuerpo, longitud_cuerpo);
}

// Recibe la petición hasta completar las cabeceras o agotar el buffer
static ssize_t recibir_peticion(int cliente, char *peticion, size_t capacidad)
{
    size_t total = 0;
    //Se reserva un byte para el terminador nulo
    while (total + 1 < capacidad) {       
        ssize_t recibidos = recv(cliente, peticion + total,
                                 capacidad - total - 1, 0);

        if (recibidos < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }

        if (recibidos == 0) {
            break;      //Cliente desconectado
        }

        total += (size_t)recibidos;
        peticion[total] = '\0'; 

        if (strstr(peticion, "\r\n\r\n") != NULL) {
            break;      //Cabeceras completas
        }
    }
    return (ssize_t)total;
}

//Procesa una conexión y selecciona la respuesta HTTP correspondiente
static void atender_cliente(int cliente)
{
    char peticion[TAMANO_PETICION];
    char metodo[8];     //7 caracteres + '\0')
    char ruta[256];     //255 caracteres + '\0')
    char version[16];   //15 caracteres + '\0')
    ssize_t recibidos;

    recibidos = recibir_peticion(cliente, peticion, sizeof(peticion));

    if (recibidos <= 0) {
        return;     
    }

    //Las anchuras limitan la escritura a cada buffer
    if (sscanf(peticion, "%7s %255s %15s", metodo, ruta, version) != 3) {
        (void)enviar_respuesta(cliente, 400, "Bad Request", "",
                               "Solicitud incorrecta\n");
        return;
    }

    if (strcmp(metodo, "GET") != 0) {
        (void)enviar_respuesta(cliente, 405, "Method Not Allowed",
                               "Allow: GET\r\n",
                               "Metodo no permitido\n");
        return;
    }

    if (strcmp(ruta, "/") == 0) {
        (void)enviar_respuesta(cliente, 200, "OK", "",
                               "Hola, mundo\n");
    } else if (strcmp(ruta, "/estado") == 0) {
        (void)enviar_respuesta(cliente, 200, "OK", "", "OK\n");
    } else {
        (void)enviar_respuesta(cliente, 404, "Not Found", "",
                               "No encontrado\n");
    }
}

int main(void)
{
    int servidor;
    int reutilizar = 1;
    struct sockaddr_in direccion; //Estructura (dirección IPv4 + puerto)

    //Evita terminar el proceso si el cliente cierra antes de recibir la respuesta
    signal(SIGPIPE, SIG_IGN);

    //AF_INET selecciona IPv4 y SOCK_STREAM crea un socket orientado a conexión
    servidor = socket(AF_INET, SOCK_STREAM, 0);
    if (servidor < 0) {
        perror("No se pudo crear el socket");
        return EXIT_FAILURE;
    }

    //Permite volver a asociar la dirección tras reiniciar el servidor
    if (setsockopt(servidor, SOL_SOCKET, SO_REUSEADDR,
                   &reutilizar, sizeof(reutilizar)) < 0) {
        perror("No se pudo configurar SO_REUSEADDR");
        close(servidor);
        return EXIT_FAILURE;
    }

    memset(&direccion, 0, sizeof(direccion));
    direccion.sin_family = AF_INET; 
    direccion.sin_addr.s_addr = htonl(INADDR_ANY);
    direccion.sin_port = htons(PUERTO);

    if (bind(servidor, (struct sockaddr *)&direccion, sizeof(direccion)) < 0) {
        perror("No se pudo asociar el socket al puerto");
        close(servidor);
        return EXIT_FAILURE;
    }

    if (listen(servidor, TAMANO_COLA) < 0) {
        perror("No se pudo poner el socket en escucha");
        close(servidor);
        return EXIT_FAILURE;
    }

    printf("Servidor HTTP disponible en el puerto %d\n", PUERTO);
    fflush(stdout);

    //Se atiende una conexión cada vez
    for (;;) {
        int cliente = accept(servidor, NULL, NULL);

        if (cliente < 0) {
            if (errno == EINTR) {
                continue; 
            }

            perror("Error al aceptar una conexion");
            close(servidor);
            return EXIT_FAILURE;
        }

        atender_cliente(cliente);
        close(cliente);
    }
}
