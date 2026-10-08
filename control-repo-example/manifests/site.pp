# Assign classes from the Hiera 'classes' array.
node default {
  lookup('classes', Array[String], 'unique', []).include
}
