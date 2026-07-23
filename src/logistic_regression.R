########################################################################
#             CASO BERKELEY 1973 — REGRESIÓN LOGÍSTICA
#                       Secciones 2.1 a 2.10
########################################################################

#--- Recordar: Descargar Librerias con install.packages("Nombre") o desde arriba en Tools: Install Packages

library(readxl)
library(lmtest)   # lrtest()
library(caret)    # confusionMatrix()
library(pROC)     # roc(), auc()

# ---  Cargar Datos ---  Recordar: Cambiar la Ruta del Archivo de Su Computadora. 
datos <- read_excel("Tarea 4 - Modelos Categoricos.xlsx", 
                                                   sheet = "admisiones.csv", range = "A1:D4527")

# Variable Respuesta: Rechazo = 1 (evento de interés), Admitido = 0
datos$Rechazo <- ifelse(datos$Estatus == "Rechazado", 1, 0)

# Género: Referencia ----------------------- Masculino es la Referencia dado que caculamos el OR: odds mujeres / odds hombres
datos$Genero <- factor(datos$Genero)
datos$Genero <- relevel(datos$Genero, ref = "Maculino")

# Departamento: Referencia
datos$Depto <- factor(datos$Deprtamento)
datos$Depto <- relevel(datos$Depto, ref = "A")

# Confirmar Niveles
levels(datos$Genero)[1]
levels(datos$Depto)[1]


########################################################################
#              Regresión logística: Rechazo ~ Género
########################################################################

modelo_genero <- glm(Rechazo ~ Genero,
                     data   = datos,
                     family = binomial(link = "logit"))

summary(modelo_genero)

# OR e Intervalos  
#-- Intercerpto = Momio Hombres & Beta1 = log-OR

cat("\n---- Coeficientes en escala Logit ----\n", coef(modelo_genero))
cat("\n---- Momios de Rechazo  ----\n", exp(coef(modelo_genero)[1]), exp(coef(modelo_genero)[1]+coef(modelo_genero)[2]))
cat("\n---- IC 95% ----\n", exp(confint(modelo_genero)))


OR_genero <- exp(coef(modelo_genero)["GeneroFemenino"])
cat(sprintf(
  "OR(Genero=Femenino) = %.4f\n
  Las mujeres tienen 1.84X más posibilidad de ser rechazadas que los hombres,
  manteniendo todo lo demás constante. Es estadísticamente significativo.
  Intercepto → momio de rechazo para Masculino = exp(%.4f) = %.4f\n\n",
  OR_genero,
  coef(modelo_genero)[1], exp(coef(modelo_genero)[1])
))


########################################################################
#            Regresión logística: Rechazo ~ Departamento
########################################################################


modelo_depto <- glm(Rechazo ~ Depto,
                    data   = datos,
                    family = binomial(link = "logit"))

summary(modelo_depto)

#-- Recordar que la Referencia = Dpto. A
cat("\n---- Coeficientes en escala Logit ----\n", coef(modelo_depto))
cat("\n---- OR's VS Dpto A ----\n",exp(coef(modelo_depto)))

cat("\n---- IC 95% ----\n",exp(confint(modelo_depto)))

cat("\n── Interpretación por departamento ─────────────────────────\n")
for (dep in c("B","C","D","E","F")) {
  coef_name <- paste0("Depto", dep)
  if (coef_name %in% names(coef(modelo_depto))) {
    OR_d <- exp(coef(modelo_depto)[coef_name])
    p_d  <- summary(modelo_depto)$coefficients[coef_name, "Pr(>|z|)"]
    sig  <- ifelse(p_d < 0.05, "Sig. ***", "NS")
    cat(sprintf("  Dpto %s: OR = %.3f  (p = %.4f) — %s\n", dep, OR_d, p_d, sig))
  }
}

cat("\n Departamento A (referencia): mejor tasa de admisión.\n")
cat("   OR > 1 indica mayor probabilidad de rechazo vs Dpto A.\n\n")


########################################################################
#             Modelo conjunto: Rechazo ~ Género + Departamento
########################################################################

modelo_ambos <- glm(Rechazo ~ Genero + Depto,
                    data   = datos,
                    family = binomial(link = "logit"))

summary(modelo_ambos)

cat("\n--- Prueba de significancia global del modelo (vs nulo)---\n")
lrtest(modelo_ambos)

cat("\n--- OR & Significancia individual de cada predictor --- \n")
coefs <- summary(modelo_ambos)$coefficients
for (nm in rownames(coefs)[-1]) {
  OR_d <- exp(coefs[nm,"Estimate"])
  p_d  <- coefs[nm, "Pr(>|z|)"]
  sig  <- ifelse(p_d < 0.05, "Sig. ***", "NS")
  cat(sprintf("%s: OR = %.3f  (p = %.4f) — %s\n", nm, OR_d, p_d, sig))
}


## ---- Signo e interpretación del coeficiente de Género (ajustado)

beta_gen  <- coef(modelo_ambos)["GeneroFemenino"]
OR_gen_aj <- exp(beta_gen)

cat(sprintf("  β(Género=Femenino) = %.4f\n", beta_gen))
cat(sprintf("  OR ajustado        = %.4f\n\n", OR_gen_aj))

if (beta_gen > 0) {
  cat("  SIGNO POSITIVO: Al controlar por departamento, ser mujer\n")
  cat("  AUMENTA ligeramente el log-momio de rechazo.\n")
} else {
  cat("  SIGNO NEGATIVO: Al controlar por departamento, ser mujer\n")
  cat("  REDUCE el log-momio de rechazo.\n")
}

cat(sprintf("\n  Comparar con OR crudo (sin ajustar): ~1.84\n"))
cat(sprintf("  OR ajustado: %.4f — la paradoja de Simpson se manifiesta aquí.\n\n", OR_gen_aj))


########################################################################
##                OR ajustado de Género vs OR_MH
########################################################################

tabla <- xtabs(~ Genero + Estatus + Deprtamento, data = datos)
mantelhaen.test(tabla) # Igual que el calculado manualmente

OR_MH <- mantelhaen.test(tabla)["estimate"]

cat(sprintf("Es similar el OR Gen Ajustado %.4f obtenido aqui al OR_MH %.4f calculado.",
            OR_gen_aj,OR_MH
            ))

########################################################################
##                IC 95% para todos los OR ajustados
########################################################################

#--- Recordar: Si el IC incluye 1. OR no significativo al 5%
OR_IC <- exp(cbind(OR = coef(modelo_ambos), confint(modelo_ambos)))
print(round(OR_IC, 4))



########################################################################
##      Modelos anidados: Nulo / Género / Género+Depto / Interacción
########################################################################


#--- Modelos
m_nulo      <- glm(Rechazo ~ 1, data = datos, family = binomial)
m_genero    <- modelo_genero                   
m_completo  <- modelo_ambos                    
m_interacc  <- glm(Rechazo ~ Genero * Depto, data = datos, family = binomial)

confint(m_interacc)

#--- Tabla Comparativa

tabla_modelos <- data.frame(
  Modelo     = c("M0: Nulo", "M1: Género", "M2: Género+Depto", "M3: Género×Depto"),
  LogLik     = round(c(logLik(m_nulo), logLik(m_genero),
                       logLik(m_completo), logLik(m_interacc)), 2),
  Devianza   = round(c(deviance(m_nulo), deviance(m_genero),
                       deviance(m_completo), deviance(m_interacc)), 2),
  GL_resid   = c(m_nulo$df.residual, m_genero$df.residual,
                 m_completo$df.residual, m_interacc$df.residual),
  AIC        = round(c(AIC(m_nulo), AIC(m_genero),
                       AIC(m_completo), AIC(m_interacc)), 2)
)
print(tabla_modelos, row.names = FALSE)

cat("\n── Pruebas LRT Modelos Anidados ──────────────────────\n")
cat("\nM0 vs M1\n");        print(lrtest(m_nulo, m_genero))
cat("\nM1 vs M2\n");  print(lrtest(m_genero, m_completo))
cat("\nM2 vs M3\n");   print(lrtest(m_completo, m_interacc))

cat("\n── Selección Mejor Modelo ──────────────────────────────\n")
aics <- c(AIC(m_nulo), AIC(m_genero), AIC(m_completo), AIC(m_interacc))
mejor <- c("M0","M1","M2","M3")[which.min(aics)]
cat(sprintf("  Menor AIC: %s (AIC = %.2f)\n", mejor, min(aics)))
cat(" M2 (Género + Departamento) es el modelo más parsimonioso:\n")
cat(" Mejora significativa sobre M1 (LRT aprox p<0.0001).\n")
cat(" La interacción (M3) mejora significativamente sobre M2 pero en menor medida.\n")
cat(" Por parsimonia se prefiere M2.\n\n")

# Modelo Seleccionado
modelo_final <- m_completo


########################################################################
#             Clasificación con punto de corte p = 0.5
########################################################################
punto_corte <- 0.5
datos$prob_rechazo <- predict(modelo_final, type = "response")
datos$clase_pred   <- ifelse(datos$prob_rechazo >= punto_corte,
                             "Rechazado", "Admitido")

mat_conf <- confusionMatrix(
  data      = factor(datos$clase_pred, levels = c("Admitido","Rechazado")),
  reference = factor(datos$Estatus,   levels = c("Admitido","Rechazado")),
  positive  = "Rechazado"
)

print(mat_conf$table)

cat(sprintf("\n  Total aspirantes: %d\n", nrow(datos)))
cat(sprintf("  Correctamente clasificados: %d  (%.1f%%)\n",
            sum(datos$clase_pred == datos$Estatus),
            mean(datos$clase_pred == datos$Estatus) * 100))

########################################################################
#             Especificidad, Sensibilidad y Accuracy
########################################################################

sens   <- mat_conf$byClass["Sensitivity"]
espec  <- mat_conf$byClass["Specificity"]
acc    <- mat_conf$overall["Accuracy"]
ppv    <- mat_conf$byClass["Pos Pred Value"]
npv    <- mat_conf$byClass["Neg Pred Value"]

cat(sprintf("  Sensibilidad  (Recall)    = %.4f  (%.1f%%)\n", sens,  sens*100))
cat(sprintf("  Especificidad             = %.4f  (%.1f%%)\n", espec, espec*100))
cat(sprintf("  Accuracy                  = %.4f  (%.1f%%)\n", acc,   acc*100))
cat(sprintf("  VPP (Precisión)           = %.4f  (%.1f%%)\n", ppv,   ppv*100))
cat(sprintf("  VPN                       = %.4f  (%.1f%%)\n\n", npv,  npv*100))

# Curva ROC y AUC
roc_obj <- roc(datos$Rechazo, datos$prob_rechazo, quiet = TRUE)
cat(sprintf("  AUC (Área bajo la curva ROC) = %.4f\n\n", auc(roc_obj)))

cat(sprintf("---- Interpretación ---- \nAccuracy %.1f%%: clasificación global correcta.",acc*100))
cat(sprintf("Sensibilidad %.1f%%: el modelo identifica correctamente al %.1f%% de los aspirantes que SERAN rechazados.\n\n", sens*100, sens*100))
cat(sprintf("Especificidad %.1f%%: el modelo identifica correctamente al %.1f%% de los aspirantes que SERAN admitidos.\n\n", espec*100, espec*100))
cat("La sensibilidad es más alta que la especificidad, lo que significa que el modelo tiende predecir 'Rechazado' con más frecuencia (clase mayoritaria).")
cat("Con un punto de corte de 0.5 el modelo está sesgado hacia predecir la clase más frecuente (61% rechazados en la muestra).")


# ----- ESTA YA TE DA TODAS LAS MÉTRICAS JEJE -----
confusionMatrix(
  as.factor(datos$clase_pred),
  as.factor(datos$Estatus),
  positive = 'Rechazado'
)
# ----- ------------------------------------- -----
